package Treex::Block::T2T::CS2CS::FixInfrequentFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

# model
has 'model'            => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'model_from_share' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );
has 'model_format'     => ( is => 'ro', isa => 'Str',        default => 'tlemma_ptlemma_pos_formeme' );

# exclusive thresholds
has 'lower_threshold' => ( is => 'ro', isa => 'Num', default => 0.2 );
has 'upper_threshold' => ( is => 'ro', isa => 'Num', default => 0.85 );

has 'lower_threshold_en' => ( is => 'ro', isa => 'Num', default => 0.1 );
has 'upper_threshold_en' => ( is => 'ro', isa => 'Num', default => 0.6 );

has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

use Treex::Tool::Depfix::CS::TagHandler;

my $model_data;

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

    # load the model file
    $model_data = do $self->model;

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

    return;
}

sub fill_node_info {
    my ( $self, $node ) = @_;

    $self->fill_info_basic($node);
    $self->fill_info_lexnode($node);
    $self->fill_info_formemes($node);
    $self->fill_info_aligned($node);
    $self->fill_info_model($node);

    return;
}

# fills in info that is provided by the model
sub fill_info_model {
    my ( $self, $node ) = @_;

    # get info from model
    $node->wild->{'deepfix_info'}->{'original_score'} =
        $self->get_formeme_score($node);
    ( $node->wild->{'deepfix_info'}->{'best_formeme'},
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

    my $formeme_count = $self->get_formeme_count($node, $formeme);
    my $all_count     = $self->get_all_count($node);

    my $score = ( $formeme_count + 1 ) / ( $all_count + 2 );

    return $score;
}

# find highest scoring formeme
# (assumes that the upper threshold is > 0.5
# and therefore it is not necessary to handle cases
# where there are two top scoring formemes --
# a random one is chosen in such case)
sub get_best_formeme {
    my ( $self, $node ) = @_;

    my $top_score   = 0;
    my $top_formeme = '';    # returned if no usable formemes in model
    my @candidates = $self->get_candidates($node);
    foreach my $candidate (@candidates) {
        my $score = $self->get_formeme_score( $node, $candidate );
        if ( $score > $top_score ) {
            $top_score   = $score;
            $top_formeme = $candidate;
        }
    }

    my $top_formeme_analyzed =
        Treex::Tool::Depfix::CS::FormemeSplitter::analyzeFormeme(
            $top_formeme);
    return ( $top_formeme_analyzed, $top_score );
}

sub fix {
    my ($self, $node) = @_;

    if ($self->decide_on_change($node)) {
        $self->do_the_change($node);
    }

    return ;
}

sub do_the_change {
    my ($self, $node) = @_;

    my $original_formeme = $node->wild->{'deepfix_info'}->{'formeme'};
    my $new_formeme = $node->wild->{'deepfix_info'}->{'best_formeme'};
    
    my $lexnode = $node->wild->{'deepfix_info'}->{'lexnode'};
    if (!defined $lexnode) {
        log_warn( "No lex node for " . tnode_sgn($node) .
            ", cannot perform the fix!" );
        return;
    }

    if ($original_formeme->{formeme} ne $new_formeme->{formeme}) {
        if ($original_formeme->{syntpos} ne $new_formeme->{syntpos}) {
            log_warn "Changing syntpos is currently not supported.";
        }
        if ($original_formeme->{case} ne $new_formeme->{case}
            && $new_formeme->{case} =~ /^[1-7]$/) {
            # change node case
            {
                my $msg = $self->change_anode_attribute (
                    'tag:case', $new_formeme->{case}, $lexnode);
                # TODO logfix
            }
            # change prep case if relevant
            if ($original_formeme->{prep} eq $new_formeme->{prep}) {
                # (otherwise it will be changed anyway)
                my $prepnode = $self->find_preposition_node(
                    $node, $original_formeme->{prep});
                if (defined $prepnode) {
                    my $msg = $self->change_anode_attribute (
                        'tag:case', $new_formeme->{case}, $prepnode, 1);
                    # TODO logfix
                }
            }
        }
        if ($original_formeme->{prep} ne $new_formeme->{prep}) {
            if ($new_formeme->{prep} eq '') {
                # remove each original prep
                foreach my $prep (@{$original_formeme->{preps}}) {
                    my $prepnode = $self->find_preposition_node(
                        $node, $original_formeme->{prep});
                    if (defined $prepnode) {
                        my $msg = $self->remove_anode($prepnode);
                        # TODO logfix
                    }
                }
            }
            elsif ($original_formeme->{prep} eq '') {
                
                # add each new prep
                foreach my $prep (@{$new_formeme->{preps}}) {
                    my $case = Treex::Tool::Depfix::CS::TagHandler->
                        get_tag_cat($child_node->tag, 'case');
                    my $prep_atts = $self->new_preposition_attributes($prep, $lexnode);
                    my $msg = $self->add_parent($prep_atts, $lexnode);
                    # TODO logfix
                }
            }
            elsif (
                scalar( @{$original_formeme->{preps}} ) == 1
                && scalar( @{$new_formeme->{preps}} ) == 1
            ) {
                # change preps 1 for 1
                # find original prep
                my $prepnode = $self->find_preposition_node(
                    $node, $original_formeme->{prep});
                if (defined $prepnode) {
                    my $msg = $self->change_anode_attribute (
                        'tag:case', $new_formeme->{case}, $prepnode, 1);
                    # TODO logfix
                }
                # change it to new prep

            }
            else {
                log_warn "Exchanging multiword preps is currently not supported."; 
            }
        }
    }


    return ;
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
    my ($self, $prep_form, $case) = @_;

    # TODO find and use the code from TectoMT
    my $prep_info = {};
    $prep_info->{form} = $prep_form;
    $prep_info->{lemma} = $prep_form; # TODO: not the best thing to do
    my $tag = Treex::Tool::Depfix::CS::TagHandler->get_empty_tag();
    $tag = Treex::Tool::Depfix::CS::TagHandler->set_tag_cat($tag, 'pos', 'R');
    $tag = Treex::Tool::Depfix::CS::TagHandler->set_tag_cat($tag, 'subpos', 'R');
    if (defined $case && $case =~ /^[1-7]$/) {
        $tag = Treex::Tool::Depfix::CS::TagHandler->set_tag_cat($tag, 'case', $case);
    }
    $prep_info->{tag} = $tag;
    
    return $prep_info;
}

# SUBS TO BE OVERRIDDEN IN EXTENDED CLASSES

sub decide_on_change {
    my ($self, $node) = @_;

    return (
        $node->wild->{'deepfix_info'}->{'best_score'} > $self->upper_threshold
        && $node->wild->{'deepfix_info'}->{'original_score'} < $self->lower_threshold
    );
}

sub get_formeme_count {
    my ($self, $node, $formeme) = @_;

    croak "FixInfrequentFormemes::get_formeme_count is an abstract method!\n";
    # return $model->{formeme_counts}->{some_info_about_node}->{$formeme}
}

sub get_all_count {
    my ($self, $node) = @_;

    croak "FixInfrequentFormemes::get_all_count is an abstract method!\n";
    # return $model->{all_counts}->{some_info_about_node}
}

sub get_candidates {
    my ($self, $node) = @_;

    croak "FixInfrequentFormemes::get_candidates is an abstract method!\n";
    # return keys $model->{formeme_counts}->{some_info_about_node}
}

# LOGGING

sub logfix_formeme {
    my ( $self, $msg ) = @_;

    my $node = undef;


    # THIS IS ONE BIG TODO :-) 

    my $log_to_treex = 0;
    my $msg    = $node->wild->{'deepfix_info'}->{'id'};
    my $parent = $node->wild->{'deepfix_info'}->{'ptlemma'}
        ?
        "$node->wild->{'deepfix_info'}->{'ptlemma'} ($node->wild->{'deepfix_info'}->{'pformeme'})"
        :
        "#root#";
    my $child = $node->wild->{'deepfix_info'}->{'enformeme'}
        ?
        "$node->wild->{'deepfix_info'}->{'tlemma'} (EN $node->wild->{'deepfix_info'}->{'enformeme'})"
        :
        $node->wild->{'deepfix_info'}->{'tlemma'};

    if ( $node->wild->{'deepfix_info'}->{'attdir'} eq '\\' ) {
        $msg .= " $parent \\ $child: ";
    }
    else {

        # assert $node->wild->{'deepfix_info'}->{'attdir'} eq '/'
        $msg .= " $child / $parent: ";
    }

    # TODO: accept there it does not have to be formeme which is changed
    $msg .= "$node->wild->{'deepfix_info'}->{'formeme'} ($node->wild->{'deepfix_info'}->{'original_score'}) ";
    if ( $node->wild->{'deepfix_info'}->{'best_formeme'} && $node->wild->{'deepfix_info'}->{'formeme'} ne $node->wild->{'deepfix_info'}->{'best_formeme'} ) {
        if ( $node->wild->{'deepfix_info'}->{'change'} ) {
            $msg .= "CHANGE TO $node->wild->{'deepfix_info'}->{'best_formeme'} ($node->wild->{'deepfix_info'}->{'best_score'})";
            $log_to_treex = 1;
        }
        else {
            $msg .= "KEEP over $node->wild->{'deepfix_info'}->{'best_formeme'} ($node->wild->{'deepfix_info'}->{'best_score'})";
        }
    }
    else {
        $msg .= "KEEP";
    }

    $self->logfix($msg, $log_to_treex);
}


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

=item C<model>

Absolute path to the model file.
Can be overridden by C<model_from_share>.

=item C<model_from_share>

Path to the model file, relative to C<share/data/models/deepfix/>.
The model file is automatically downloaded if missing locally but available online.
Overrides C<model>.
Default is undef.

=item C<log_to_console>

Set to C<1> to log details about the changes performed, using C<log_info()>.
Default is C<0>.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
