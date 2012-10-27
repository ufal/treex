package Treex::Block::T2T::CS2CS::FixInfrequentFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 0 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'alignment_type'  => ( is       => 'rw', isa => 'Str', default => 'copy' );
has 'log_to_console'  => ( is       => 'rw', isa => 'Bool', default => 0 );

# model
has 'model'            => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'model_from_share' => ( is => 'ro', isa => 'Maybe[Str]', default => undef );

# exclusive thresholds
has 'lower_threshold' => ( is => 'ro', isa => 'Num', default => 0.2 );
has 'upper_threshold' => ( is => 'ro', isa => 'Num', default => 0.85 );

my $model_data;

use Treex::Tool::Lexicon::CS;

sub process_start {
    my $self = shift;

    # find the model file
    if ( defined $self->model_from_share ) {
        my $model = require_file_from_share(
	    'data/models/deepfix/' . $self->model_from_share );
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

sub process_tnode {
    my ( $self, $node ) = @_;

    # get info about current node
    my $node_info = { 'node' => $node };
    $self->fill_info_from_tree($node_info);
    $self->fill_info_from_model($node_info);

    # decide whether to change the formeme
    $self->decide_on_change($node_info);

    # change the current formeme if it seems to be a good idea
    if ( $node_info->{'change'} ) {
        $node->set_formeme( $node_info->{'best_formeme'} );
        # mark this node to apply the change in later stages
	$node->wild->{'change_by_deepfix'} = 1;
    }

    # log
    $self->logfix($node_info);

    return;
}

# fills in info that is stored in the tree
sub fill_info_from_tree {
    my ( $self, $node_info ) = @_;

    # id
    $node_info->{'id'} = $node_info->{'node'}->id;
    {
        my $lang = $self->language;
        my $sel  = $self->selector;
        $node_info->{'id'} =~ s/t_tree-${lang}_${sel}-//;
    }

    # parent
    $node_info->{'parent'} = $node_info->{'node'}->get_eparents( { first_only => 1, or_topological => 1 } );

    # lemmas (cut the rubbish from the lemma)
    $node_info->{'tlemma'} = Treex::Tool::Lexicon::CS::truncate_lemma(
	$node_info->{'node'}->t_lemma(), 1);
    $node_info->{'ptlemma'} = Treex::Tool::Lexicon::CS::truncate_lemma(
	$node_info->{'parent'}->t_lemma() || '', 1);

    # formemes
    $node_info->{'formeme'} = $node_info->{'node'}->formeme();
    $node_info->{'pformeme'} = $node_info->{'parent'}->formeme() || '';

    # POSes
    ( $node_info->{'syntpos'}, $node_info->{'preps'}, $node_info->{'case'} )
        = splitFormeme( $node_info->{'formeme'} );
    ( $node_info->{'psyntpos'}, $node_info->{'ppreps'}, $node_info->{'pcase'} )
        = splitFormeme( $node_info->{'pformeme'} );

    $node_info->{'mpos'} = '?';
    my ($orig_node) = $node_info->{'node'}->get_aligned_nodes_of_type(
	$self->alignment_type
	);
    if (defined $orig_node) {
	my $lex_anode = $orig_node->get_lex_anode();
	if (defined $lex_anode) {
	    $node_info->{'mpos'} = substr ($lex_anode->tag, 0, 1);
	}
	else {
	    log_warn ("T-node " . $orig_node->id . " has no lex node!");
	}
    }

    # attdir
    if ( $node_info->{'node'}->ord < $node_info->{'parent'}->ord ) {
	$node_info->{'attdir'} = '/';
    }
    else {
	$node_info->{'attdir'} = '\\';
    }

    return $node_info;
}

# returns ($syntpos, \@preps, $case)
sub splitFormeme {
    my ($formeme) = @_;

    # n:
    # n:2
    # n:attr
    # n:v+6

    # defaults
    my $syntpos  = $formeme;
    my $prep = '';
    my $case = '';         # 1-7, X, attr, poss

    if ( $formeme =~ /^([a-z]+):(.*)$/ ) {
        $syntpos  = $1;
        $case = $2;
        if ( $case =~ /^(.*)\+(.*)$/ ) {
            $prep = $1;
            $case = $2;
        }
    }

    my @preps = split /_/, $prep;

    return ( $syntpos, \@preps, $case );
}

# fills in info that is provided by the model
sub fill_info_from_model {
    my ( $self, $node_info ) = @_;

    # get info from model
    $node_info->{'original_score'} =
        $self->get_formeme_score($node_info);
    ( $node_info->{'best_formeme'}, $node_info->{'best_score'} ) =
        $self->get_best_formeme($node_info);
    ( $node_info->{'bpos'}, $node_info->{'bpreps'}, $node_info->{'bcase'} )
	= splitFormeme( $node_info->{'best_formeme'} );

    return $node_info;
}

# uses the model to compute the score of the given formeme
# (or the original formeme if no formeme is given)
# NB: this is *it*, this is what actually decides the fix
# Now this is simply MLE with +1 smoothing, but backoff could be provided
# and eventually there should be some "real" machine learning here
sub get_formeme_score {
    my ( $self, $node_info, $formeme ) = @_;
    if ( !defined $formeme ) {
        $formeme = $node_info->{'formeme'};
    }

    my $formeme_count = $model_data->{'tlemma_ptlemma_pos_formeme'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }->{$formeme}
        || 0;
    my $all_count = $model_data->{'tlemma_ptlemma_pos'}
        ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }
        || 0;

    my $score = ( $formeme_count + 1 ) / ( $all_count + 2 );

    return $score;
}

# find highest scoring formeme
# (assumes that the upper threshold is > 0.5
# and therefore it is not necessary to handle cases
# where there are two top scoring formemes --
# a random one is chosen in such case)
sub get_best_formeme {
    my ( $self, $node_info ) = @_;

    my @candidates = keys %{
        $model_data->{'tlemma_ptlemma_pos_formeme'}
            ->{ $node_info->{'tlemma'} }->{ $node_info->{'ptlemma'} }->{ $node_info->{'syntpos'} }
        };

    my $top_score   = 0;
    my $top_formeme = '';    # returned if no usable formemes in model

    foreach my $candidate (@candidates) {
        my $score = $self->get_formeme_score( $node_info, $candidate );
        if ( $score > $top_score ) {
            $top_score   = $score;
            $top_formeme = $candidate;
        }
    }

    return ( $top_formeme, $top_score );
}

# decide whether to change the formeme,
# based on the scores and the thresholds
sub decide_on_change {
    my ( $self, $node_info ) = @_;

    # fix only Ns with no or one aux node
    # (to be tuned and eventually made more efficient)
    # TODO: this should be also respected in the model!
    if (
	$node_info->{'syntpos'} eq 'n' # fix only syntactical nouns
	&& @{ $node_info->{'preps'} } <= 1 # do not fix multiword prepositions
	&& @{ $node_info->{'preps'} } == @{ $node_info->{'bpreps'} } # do not add or remove nodes
	&& $node_info->{'mpos'} ne 'P' # do not fix morphological pronouns
	) {
        $node_info->{'change'} = (
            ( $node_info->{'original_score'} < $self->lower_threshold )
	    &&
	    ( $node_info->{'best_score'} > $self->upper_threshold )
        );
    }
    else {
        $node_info->{'change'} = 0;
    }

    return $node_info->{'change'};
}

sub logfix {
    my ( $self, $node_info ) = @_;

    my $msg    = $node_info->{'id'};
    my $parent = $node_info->{'ptlemma'}
        ?
        "$node_info->{'ptlemma'} ($node_info->{'pformeme'})"
        :
        "#root#";
    if ( $node_info->{'attdir'} eq '\\' ) {
        $msg .= " $parent \\ $node_info->{'tlemma'}: ";
    }
    else {
	# assert $node_info->{'attdir'} eq '/'
        $msg .= " $node_info->{'tlemma'} / $parent: ";
    }
    $msg .= "$node_info->{'formeme'} ($node_info->{'original_score'}) ";
    if ( $node_info->{'best_formeme'} && $node_info->{'formeme'} ne $node_info->{'best_formeme'} ) {
        if ( $node_info->{'change'} ) {
            $msg .= "CHANGE TO $node_info->{'best_formeme'} ($node_info->{'best_score'})";
        }
        else {
            $msg .= "KEEP over $node_info->{'best_formeme'} ($node_info->{'best_score'})";
        }
    }
    else {
        $msg .= "KEEP";
    }

    if ( $node_info->{'change'} ) {

        # log to treex file
        my $fixzone = $node_info->{'node'}->get_bundle()->get_or_create_zone( $self->language, 'deepfix' );
        my $sentence = $fixzone->sentence;
        if ($sentence) {
            $sentence .= " [$msg]";
        }
        else {
            $sentence = "[$msg]";
        }
        $fixzone->set_sentence($sentence);
    }

    # log to console
    if ( $self->log_to_console ) {
        log_info($msg);
    }

    return;
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

=item C<alignment_type>

Type of alignment between the t-trees.
Default is C<copy>.
The alignemt must lead from this zone to the other zone.
(This all is true by default if the t-tree in this zone was created with
L<T2T::CopyTtree>.)

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
