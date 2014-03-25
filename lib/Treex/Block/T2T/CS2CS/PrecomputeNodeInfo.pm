package Treex::Block::T2T::CS2CS::PrecomputeNodeInfo;
use Moose;
use Treex::Core::Common;
use utf8;
use Carp;
extends 'Treex::Core::Block';

has '+language'          => ( required => 1 );
has 'src_alignment_type' => ( is       => 'rw', isa => 'Str', default => 'src' );
has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

use Treex::Tool::Lexicon::CS;
use Treex::Tool::Depfix::CS::FormemeSplitter;
use Treex::Tool::Depfix::CS::TagHandler;

sub process_tnode {
    my ( $self, $node ) = @_;

    $self->fill_info_basic($node);
    $self->fill_info_lexnode($node);
    $self->fill_info_formemes($node);
    $self->fill_info_aligned($node);
    
    return;
}

sub fill_info_basic {
    my ( $self, $node ) = @_;

    # id
    $node->wild->{'deepfix_info'}->{'id'} = $node->id;
    {
        my $lang = $self->language;
        my $sel  = $self->selector;
        $node->wild->{'deepfix_info'}->{'id'} =~ s/t_tree-${lang}_${sel}-//;
    }

    # parent
    my $parent = $node->get_eparents( { first_only => 1, or_topological => 1 } );
    $node->wild->{'deepfix_info'}->{'parent'} = $parent;

    # lemmas (cut the rubbish from the lemma)
    $node->wild->{'deepfix_info'}->{'tlemma'} =
        Treex::Tool::Lexicon::CS::truncate_lemma( $node->t_lemma(), 1);
    $node->wild->{'deepfix_info'}->{'ptlemma'} =
        Treex::Tool::Lexicon::CS::truncate_lemma( $parent->t_lemma() || '', 1);

    # attdir
    if ( $node->ord < $parent->ord ) {
        $node->wild->{'deepfix_info'}->{'attdir'} = '/';
    }
    else {
        $node->wild->{'deepfix_info'}->{'attdir'} = '\\';
    }

    return $node;
}

# (p)formeme->[formeme|syntpos|case|prep|preps]
sub fill_info_formemes {
    my ( $self, $node ) = @_;

    $node->wild->{'deepfix_info'}->{'formeme'} =
        Treex::Tool::Depfix::CS::FormemeSplitter::analyzeFormeme(
        $node->formeme
        );
    $node->wild->{'deepfix_info'}->{'pformeme'} =
        Treex::Tool::Depfix::CS::FormemeSplitter::analyzeFormeme(
        $node->wild->{'deepfix_info'}->{'parent'}->formeme
        );

    return $node;
}

sub fill_info_aligned {
    my ( $self, $node ) = @_;

    ( $node->wild->{'deepfix_info'}->{'ennode'} ) = $node->get_aligned_nodes_of_type(
        $self->src_alignment_type
    );
    if ( defined $node->wild->{'deepfix_info'}->{'ennode'} ) {
        $node->wild->{'deepfix_info'}->{'enformeme'} = $node->wild->{'deepfix_info'}->{'ennode'}->formeme() // '';
        $node->wild->{'deepfix_info'}->{'entlemma'}  = $node->wild->{'deepfix_info'}->{'ennode'}->t_lemma() // '';
        $node->wild->{'deepfix_info'}->{'enfunctor'} =
            $node->wild->{'deepfix_info'}->{'ennode'}->functor() // '';
    }
    else {
        $node->wild->{'deepfix_info'}->{'enformeme'} = '';
        $node->wild->{'deepfix_info'}->{'entlemma'}  = '';
        $node->wild->{'deepfix_info'}->{'enfunctor'} = '';
    }

    return $node;
}

sub fill_info_lexnode {
    my ( $self, $node ) = @_;

    my $result = 0;

    my $lexnode = $node->get_lex_anode();
    $node->wild->{'deepfix_info'}->{'lexnode'} = $lexnode;
    if ( defined $lexnode ) {
        
        # mpos
        $node->wild->{'deepfix_info'}->{'mpos'} = substr( $lexnode->tag, 0, 1 );
        
        # id
        my $lexnode_id = $lexnode->id;
        {
            my $lang = $self->language;
            my $sel  = $self->selector;
            $lexnode_id =~ s/a_tree-${lang}_${sel}-//;
        }
        $lexnode->wild->{'deepfix_info'}->{'id'} = $lexnode_id;

        # ennode
        ( $lexnode->wild->{'deepfix_info'}->{'ennode'} ) =
            $lexnode->get_aligned_nodes_of_type( $self->src_alignment_type);

        $result = 1;
    }
    else {
        if (!defined $node->formeme | $node->formeme ne 'drop') {
            # $node->wild->{'deepfix_info'}->{'mpos'} = '?';
            # log_warn( "T-node " . $self->tnode_sgn($node) . " has no lex node!" );
        }
    }

    return $result;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::PrecomputeNodeInfo

=head1 DESCRIPTION

Fills in some interesting data into each node->wild->{deepfix_info}
to be used by Deepfix blocks.

=head1 PARAMETERS

=over

=item C<src_alignment_type>

Type of alignment between the cs_Tfix t-tree and the en t-tree.
Default is C<src>.
The alignemt must lead from cs_Tfix to en.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
