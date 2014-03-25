package Treex::Block::T2T::CS2CS::FixInfrequentFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
use Carp;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

# model
has 'model'            => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'model_data'       => ( is => 'rw', isa => 'Maybe[HashRef]', default => undef );
has 'model_from_share' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'model_format'     => ( is => 'rw', isa => 'Str', default => 'tlemma_ptlemma_syntpos_enformeme_formeme' );

# exclusive thresholds
has 'lower_threshold' => ( is => 'ro', isa => 'Num', default => 1 );
has 'upper_threshold' => ( is => 'ro', isa => 'Num', default => 1 );

has 'lower_threshold_en' => ( is => 'ro', isa => 'Num', default => 1 );
has 'upper_threshold_en' => ( is => 'ro', isa => 'Num', default => 0.6 );

has 'min_count_to_keep' => ( is => 'rw', isa => 'Num', default => 2 );

use Treex::Tool::Depfix::CS::TagHandler;

# already loaded models (not to be loaded multiple times)
my $loaded_models = {};

sub process_start {
    my $self = shift;

    # find the model file
    if ( defined $self->model_from_share ) {
        my $model = require_file_from_share(
            'data/models/deepfix/' . $self->model_from_share
        );
        $self->set_model($model);
    }
    if ( !defined $self->model ) {
        log_fatal("Either model or model_from_share parameter must be set!");
    }

    if (defined $loaded_models->{$self->model}) {
        # this model is already loaded, just set it
        $self->set_model_data($loaded_models->{$self->model});
    }
    else {
        # load the model file
        my $model_data = do $self->model;
    
        # handle errors
        if ( !$model_data ) {
            if ($@) {
                log_fatal "Cannot parse file " . $self->model . ": $@";
            }
            elsif ( !defined $model_data ) {
                log_fatal "Cannot read file " . $self->model . ": $!";
            }
            else {
                log_fatal "Cannot load data from file " . $self->model;
            }
        }
        else {
            $self->set_model_data($model_data);
            $loaded_models->{$self->model} = $model_data; 
        }
    }

    $self->SUPER::process_start;

    return;
}

# fills in info that is provided by the model
sub fill_info_model {
    my ( $self, $node ) = @_;

    # get info from model
    $node->wild->{'deepfix_info'}->{'original_score'} =
        $self->get_formeme_score($node);
    (   $node->wild->{'deepfix_info'}->{'best_formeme'},
        $node->wild->{'deepfix_info'}->{'best_score'}
    ) = $self->get_best_formeme($node);

    return $node;
}

# uses the model to compute the score of the given formeme
# (or the original formeme if no formeme is given)
# NB: this is *it*, this is what actually decides the fix
# Now this is simply MLE with +1 smoothing, but backoff could be provided
# and eventually there should be some "real" machine learning here
sub get_formeme_score {
    my ( $self, $node, $formeme ) = @_;
    if ( !defined $formeme ) {
        $formeme = $node->wild->{'deepfix_info'}->{'formeme'}->{'formeme'};
    }

    my $formeme_count = $self->get_formeme_count( $node, $formeme );
    my $all_count = $self->get_all_count($node);

    # TODO: this is smoothing, but presumably even worse than "add 1"
    # a linear interpolation smoothing might do a good job?
    my $score = ( $formeme_count + 1 ) / ( $all_count + 2 );

    # ignore low counts
    if ( $all_count < $self->min_count_to_keep) {
        # 0.5 is returned if we have no data whatsoever
        # (all formemes get a uniform prob of 0.5)
        $score = 0.5;
    }

    return $score;
}

# find highest scoring formeme
# (assumes that the upper threshold is > 0.5
# and therefore it is not necessary to handle cases
# where there are two top scoring formemes --
# a random one is chosen in such case)
sub get_best_formeme {
    my ( $self, $node ) = @_;

    my $original_formeme = $node->formeme;
    my $top_score        = 0;
    my $top_formeme      = undef;
    my @candidates       = $self->get_candidates($node);
    foreach my $candidate (@candidates) {
        next if ( $candidate eq $original_formeme );
        my $score = $self->get_formeme_score( $node, $candidate );
        if ( $score > $top_score ) {
            $top_score   = $score;
            $top_formeme = $candidate;
        }
    }

    my $top_formeme_analyzed =
        Treex::Tool::Depfix::CS::FormemeSplitter::analyzeFormeme(
        $top_formeme
        );
    return ( $top_formeme_analyzed, $top_score );
}

sub fix {
    my ( $self, $node ) = @_;

    # precompute information from model
    $self->fill_info_model($node);

    # do the change
    my $decide_on_change_result = $self->decide_on_change($node);
    if ( $decide_on_change_result == 1 ) {

        # log the intention
        log_info(
            $self->tnode_sgn($node) . ': '
                . 'trying to change ' . $node->formeme
                . ' (' . $node->wild->{'deepfix_info'}->{'original_score'} . ') '
                . 'to '
                . $node->wild->{'deepfix_info'}->{'best_formeme'}->{'formeme'}
                . ' (' . $node->wild->{'deepfix_info'}->{'best_score'} . ')'
        );

        # try to do the change
        my $msg = $self->do_the_change($node);

        # log the result
        if ($msg) {
            $self->logfix( "Deepfix $msg", 1 );
        }
    }

    # or do not do the change
    elsif ($decide_on_change_result == 0) {

        # keep original formeme
        my $msg =
            $self->tnode_sgn($node) . ': '
            . 'keep ' . $node->formeme
            . ' (' . $node->wild->{'deepfix_info'}->{'original_score'} . ') ';

        # over best alternative formeme
        if ( $node->wild->{'deepfix_info'}->{'best_formeme'}->{'formeme'} ) {
            $msg .=
                'over '
                . $node->wild->{'deepfix_info'}->{'best_formeme'}->{'formeme'}
                . ' (' . $node->wild->{'deepfix_info'}->{'best_score'} . ')'
        }

        log_info($msg);
    }
    
    # otherwise the change was not even considered
    # because the node does not fit the block constraints

    return;
}

sub do_the_change {
    my ( $self, $node ) = @_;

    # fix log message
    # is additively constructed during the fixing
    # and returned at the end
    # if premature return is not invoked
    my $msg = '';

    my $original_formeme = $node->wild->{'deepfix_info'}->{'formeme'};
    my $new_formeme      = $node->wild->{'deepfix_info'}->{'best_formeme'};

    my $lexnode = $node->wild->{'deepfix_info'}->{'lexnode'};
    if ( !defined $lexnode ) {
        log_warn(
            "No lex node for "
                . $self->tnode_sgn($node)
                .
                ", cannot perform the fix!"
        );
        return;
    }

    if ( $original_formeme->{formeme} ne $new_formeme->{formeme} ) {

        # fix syntpos
        if ( $original_formeme->{syntpos} ne $new_formeme->{syntpos} ) {
            log_warn "Changing syntpos is currently not supported.";
            return;
        }

        # fix preposition
        if ( $original_formeme->{prep} ne $new_formeme->{prep} ) {

            # deleting prep(s)
            if ( $new_formeme->{prep} eq '' ) {

                # remove each original prep
                foreach my $prep ( @{ $original_formeme->{preps} } ) {
                    my $prepnode = $self->find_preposition_node(
                        $node, $original_formeme->{prep}
                    );
                    if ( defined $prepnode ) {
                        $msg .= $self->remove_anode($prepnode);
                    }
                }
            }

            # adding new prep(s)
            elsif ( $original_formeme->{prep} eq '' ) {

                # add each new prep
                foreach my $prep ( @{ $new_formeme->{preps} } ) {
                    my $prep_atts = $self->new_preposition_attributes(
                        $prep, $new_formeme->{case}
                    );
                    $msg .= $self->add_parent( $prep_atts, $lexnode );
                }
            }

            # changing preps 1 for 1
            elsif (
                scalar( @{ $original_formeme->{preps} } ) == 1
                && scalar( @{ $new_formeme->{preps} } ) == 1
                )
            {

                # find original prep
                my $prepnode = $self->find_preposition_node(
                    $node, $original_formeme->{prep}
                );

                # change it to new prep
                if ( defined $prepnode ) {
                    my $prep_atts = $self->new_preposition_attributes(
                        $new_formeme->{prep}, $new_formeme->{case}
                    );
                    $msg .= $self->change_anode_attributes(
                        $prepnode, $prep_atts, 1
                    );
                }

            }
            else {
                log_warn "Exchanging multiword preps is currently not supported.";
                return;
            }
        }

        # fix case
        if ($original_formeme->{case} ne $new_formeme->{case}
            && $new_formeme->{case} =~ /^[1-7]$/
            )
        {

            # change node case
            $msg .= $self->change_anode_attribute(
                $lexnode, 'tag:case', $new_formeme->{case}
            );

            # change prep case if relevant
            if ( $original_formeme->{prep} eq $new_formeme->{prep} ) {

                # (otherwise it has already been changed anyway)
                my $prepnode = $self->find_preposition_node(
                    $node, $original_formeme->{prep}
                );
                if ( defined $prepnode ) {
                    $msg .= $self->change_anode_attribute(
                        $prepnode, 'tag:case', $new_formeme->{case}, 1
                    );
                }
            }

            # change *:attr children cases (recursively)
            if ( $self->magic !~ /nottr/ ) {
                $msg .= $self->change_attr_echildren($node, $new_formeme->{case});
            }

        }

        # set the new formeme
        $node->set_formeme($new_formeme->{formeme});

        return $msg;
    }
    else {
        log_warn "No change to be done, the formemes are the same!";
        return;
    }
}

my $max_recursion = 5;
sub change_attr_echildren {
    my ($self, $node, $newcase) = @_;

    my $msg = '';

    my @attr_children = grep { $_->formeme =~ /:(attr|poss)$/ }
        $node->get_echildren();
    foreach my $child (@attr_children) {
        my $child_lexnode =
            $child->wild->{'deepfix_info'}->{'lexnode'};
        # change node case
        $msg .= ' [*:attr] ';
        $msg .= $self->change_anode_attribute(
            $child_lexnode, 'tag:case', $newcase
        );
        if ( $max_recursion > 0 ) {
            $max_recursion--;
            $self->change_attr_echildren($node, $newcase);
            $max_recursion++;
        }
    }

    return $msg;
}

sub find_preposition_node {
    my ( $self, $tnode, $prep_form ) = @_;

    my $prep_node = undef;

    my @matching_aux_nodes = grep {
        $_->form =~ /^${prep_form}e?$/i
    } $tnode->get_aux_anodes();
    if ( @matching_aux_nodes == 1 ) {
        $prep_node = $matching_aux_nodes[0];
    }
    else {

        # else no prep can be found, which is often a valid result
        if ( @matching_aux_nodes == 0 ) {
            log_warn("There is no matching aux node!");
        }
        else {
            log_warn("There are more than one matching aux nodes!");
        }
    }

    return $prep_node;
}

sub new_preposition_attributes {
    my ( $self, $prep_form, $case ) = @_;

    # TODO find and use the code from TectoMT
    my $prep_info = {};
    $prep_info->{form}  = $prep_form;
    $prep_info->{lemma} = $prep_form;    # TODO: not the best thing to do
    my $tag = Treex::Tool::Depfix::CS::TagHandler::get_empty_tag();
    $tag = Treex::Tool::Depfix::CS::TagHandler::set_tag_cat( $tag, 'pos',    'R' );
    $tag = Treex::Tool::Depfix::CS::TagHandler::set_tag_cat( $tag, 'subpos', 'R' );
    if ( defined $case && $case =~ /^[1-7]$/ ) {
        $tag = Treex::Tool::Depfix::CS::TagHandler::set_tag_cat( $tag, 'case', $case );
    }
    $prep_info->{tag} = $tag;

    return $prep_info;
}

sub numerals_are_around {
    my ($self, $node) = @_;

    my $result = 0;

    # checked on EN tree as the CS tree structure cannot be believed much;
    # were the CS tree better, it would be better to check the CS tree
    my $ennode = $node->wild->{'deepfix_info'}->{'ennode'};
    if ( defined $ennode ) {
        $result = any { $_->t_lemma =~ /[0-9]/
                || $_->t_lemma
                    =~ /^(much|many|more|most|few|little|less|least)$/
            } $ennode->get_echildren( {or_topological => 1} );
    }

    return $result;
}

# SUBS TO BE OVERRIDDEN IN EXTENDED CLASSES

sub decide_on_change {
    my ( $self, $node ) = @_;

    return $self->decide_on_change_en_model($node);
}

sub decide_on_change_base_model {
    my ($self, $node) = @_;

    return
        ( $node->wild->{'deepfix_info'}->{'best_score'} > $self->upper_threshold )
        &&
        ( $node->wild->{'deepfix_info'}->{'original_score'} < $self->lower_threshold )
    ;
}

sub decide_on_change_en_model {
    my ($self, $node) = @_;

    if ( $node->wild->{'deepfix_info'}->{'enformeme'} ) {
        return
            ( $node->wild->{'deepfix_info'}->{'best_score'} > $self->upper_threshold_en )
            &&
            ( $node->wild->{'deepfix_info'}->{'original_score'} < $self->lower_threshold_en )
        ;
    }
    else {
        return
            ( $node->wild->{'deepfix_info'}->{'best_score'} > $self->upper_threshold )
            &&
            ( $node->wild->{'deepfix_info'}->{'original_score'} < $self->lower_threshold )
        ;
    }
}

sub get_formeme_count {
    my ( $self, $node, $formeme ) = @_;

    my $model_format = $self->model_format;
    if ( $model_format eq 'tlemma_ptlemma_syntpos_enformeme_formeme') {
        return $self->model_data->{'tlemma_ptlemma_syntpos_enformeme_formeme'}
        ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        ->{$formeme}
        || 0;
    }
    elsif ( $model_format eq 'ptlemma_syntpos_enformeme_formeme') {
        return $self->model_data->{'ptlemma_syntpos_enformeme_formeme'}
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        ->{$formeme}
        || 0;
    }
    elsif ( $model_format eq 'tlemma_ptlemma_syntpos_enfunctor_formeme') {
        return $self->model_data->{'tlemma_ptlemma_syntpos_enfunctor_formeme'}
        ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enfunctor'} }
        ->{$formeme}
        || 0;
    }
    else {
        log_fatal "Unknown model format: $model_format";
        return;
    }
}

sub get_all_count {
    my ( $self, $node ) = @_;

    my $model_format = $self->model_format;
    if ( $model_format eq 'tlemma_ptlemma_syntpos_enformeme_formeme') {
        return $self->model_data->{'tlemma_ptlemma_syntpos_enformeme'}
        ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        || 0;
    }
    elsif ( $model_format eq 'ptlemma_syntpos_enformeme_formeme') {
        return $self->model_data->{'ptlemma_syntpos_enformeme'}
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        || 0;
    }
    elsif ( $model_format eq 'tlemma_ptlemma_syntpos_enfunctor_formeme') {
        return $self->model_data->{'tlemma_ptlemma_syntpos_enfunctor'}
        ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
        ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
        ->{ $node->wild->{'deepfix_info'}->{'enfunctor'} }
        || 0;
    }
    else {
        log_fatal "Unknown model format: $model_format";
        return;
    }
}

sub get_candidates {
    my ( $self, $node ) = @_;

    my $model_format = $self->model_format;
    if ( $model_format eq 'tlemma_ptlemma_syntpos_enformeme_formeme') {
        return keys %{
            $self->model_data->{'tlemma_ptlemma_syntpos_enformeme_formeme'}
            ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
            ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
            ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
            ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        };
    }
    elsif ( $model_format eq 'ptlemma_syntpos_enformeme_formeme') {
        return keys %{
            $self->model_data->{'ptlemma_syntpos_enformeme_formeme'}
            ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
            ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
            ->{ $node->wild->{'deepfix_info'}->{'enformeme'} }
        };
    }
    elsif ( $model_format eq 'tlemma_ptlemma_syntpos_enfunctor_formeme') {
        return keys %{
            $self->model_data->{'tlemma_ptlemma_syntpos_enfunctor_formeme'}
            ->{ $node->wild->{'deepfix_info'}->{'tlemma'} }
            ->{ $node->wild->{'deepfix_info'}->{'ptlemma'} }
            ->{ $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} }
            ->{ $node->wild->{'deepfix_info'}->{'enfunctor'} }
        };
    }
    else {
        log_fatal "Unknown model format: $model_format";
        return;
    }
}

# sub get_formeme_count {
#     my ( $self, $node, $formeme ) = @_;
# 
#     croak "FixInfrequentFormemes::get_formeme_count is an abstract method!\n";
# 
#     # return $model->{formeme_counts}->{some_info_about_node}->{$formeme}
# }
# 
# sub get_all_count {
#     my ( $self, $node ) = @_;
# 
#     croak "FixInfrequentFormemes::get_all_count is an abstract method!\n";
# 
#     # return $model->{all_counts}->{some_info_about_node}
# }
# 
# sub get_candidates {
#     my ( $self, $node ) = @_;
# 
#     croak "FixInfrequentFormemes::get_candidates is an abstract method!\n";
# 
#     # return keys $model->{formeme_counts}->{some_info_about_node}
# }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixInfrequentFormemes -
An attempt to replace infrequent formemes by some more frequent ones.
(A Deepfix block.)

=head1 DESCRIPTION

An attempt to replace infrequent formemes by some more frequent ones.

Each node's formeme is checked against certain conditions --
currently, we attempt to fix only formemes of syntactical nouns
that are not morphological pronouns and that have no or one preposition.
Each such formeme is scored against the C<model> -- currently this is
a +1 smoothed MLE on CzEng data; the node's formeme is conditioned by
the t-lemma of the node and the t-lemma of its effective parent.
If the score of the current formeme is below C<lower_threshold>
and the score of the best scoring alternative formeme
is above C<upper_threshold>, the change is performed.

=head1 PARAMETERS

=over

=item C<lower_threshold>

Only formemes with a score below C<lower_threshold> are fixed.
Default is 0.2.

=item C<upper_threshold>

Formemes are only changed to formemes with a score above C<upper_threshold>.
Default is 0.85.

=item C<lower_threshold_en>

If there is an aligned formeme,
only a formeme with a score below C<lower_threshold_en> is fixed.

=item C<upper_threshold_en>

If there is an aligned formeme,
a formeme is only changed to a formeme with a score above C<upper_threshold_en>.

=item C<model>

Absolute path to the model file.
Can be overridden by C<model_from_share>.

=item C<model_from_share>

Path to the model file, relative to C<share/data/models/deepfix/>.
The model file is automatically downloaded if missing locally but available online.
Overrides C<model>.
Default is undef.


=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
