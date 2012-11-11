package Treex::Block::T2T::CS2CS::Deepfix;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'           => ( required => 1 );
has 'source_language'     => ( is       => 'rw', isa => 'Str', required => 0 );
has 'source_selector'     => ( is       => 'rw', isa => 'Str', default => '' );
has 'orig_alignment_type' => ( is       => 'rw', isa => 'Str', default => 'orig' );
has 'src_alignment_type'  => ( is       => 'rw', isa => 'Str', default => 'src' );
has 'log_to_console'      => ( is       => 'rw', isa => 'Bool', default => 0 );

has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

use Treex::Tool::Lexicon::CS;
use Treex::Tool::Depfix::CS::FormemeSplitter;

sub process_tnode {
    my ( $self, $node ) = @_;

    # get info about current node
    my $node_info = { 'node' => $node };
    $self->fill_node_info($node_info);

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

sub fill_node_info {
    my ( $self, $node_info ) = @_;

    $self->fill_info_from_tree($node_info);

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
        $node_info->{'node'}->t_lemma(), 1
    );
    $node_info->{'ptlemma'} = Treex::Tool::Lexicon::CS::truncate_lemma(
        $node_info->{'parent'}->t_lemma() || '', 1
    );

    # formemes
    $node_info->{'formeme'} = $node_info->{'node'}->formeme();
    $node_info->{'pformeme'} = $node_info->{'parent'}->formeme() || '';
    ( $node_info->{'ennode'} ) = $node_info->{'node'}->get_aligned_nodes_of_type(
        $self->src_alignment_type
    );
    $node_info->{'enformeme'} = (
        defined $node_info->{'ennode'} && $node_info->{'ennode'}->formeme()
        ?
            $node_info->{'ennode'}->formeme()
        :
            ''
    );

    # POSes
    ( $node_info->{'syntpos'}, $node_info->{'preps'}, $node_info->{'case'} )
        = Treex::Tool::Depfix::CS::FormemeSplitter::splitFormeme(
        $node_info->{'formeme'}
        );
    ( $node_info->{'psyntpos'}, $node_info->{'ppreps'}, $node_info->{'pcase'} )
        = Treex::Tool::Depfix::CS::FormemeSplitter::splitFormeme(
        $node_info->{'pformeme'}
        );

    $node_info->{'mpos'} = '?';
    my ($orig_node) = $node_info->{'node'}->get_aligned_nodes_of_type(
        $self->orig_alignment_type
    );
    if ( defined $orig_node ) {
        my $lex_anode = $orig_node->get_lex_anode();
        if ( defined $lex_anode ) {
            $node_info->{'mpos'} = substr( $lex_anode->tag, 0, 1 );
        }
        else {
            log_warn( "T-node " . $orig_node->id . " has no lex node!" );
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

# decide whether to change the formeme,
sub decide_on_change {
    my ( $self, $node_info ) = @_;

    $node_info->{'change'} = 0;

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
    my $child = $node_info->{'enformeme'}
        ?
        "$node_info->{'tlemma'} (EN $node_info->{'enformeme'})"
        :
        $node_info->{'tlemma'};

    if ( $node_info->{'attdir'} eq '\\' ) {
        $msg .= " $parent \\ $child: ";
    }
    else {

        # assert $node_info->{'attdir'} eq '/'
        $msg .= " $child / $parent: ";
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

=item C<orig_alignment_type>

Type of alignment between the CS t-trees.
Default is C<orig>.
The alignment must lead from this zone to the other zone.

=item C<src_alignment_type>

Type of alignment between the cs_Tfix t-tree and the en t-tree.
Default is C<src>.
The alignemt must lead from cs_Tfix to en.

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
