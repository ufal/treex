package Treex::Block::Align::T::PCEDTAlignment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_selector => ( isa => 'Str', is => 'ro', default  => '' );

sub process_ttree {
    my ( $self, $troot ) = @_;

    my $to_troot = $troot->get_bundle->get_tree( $self->to_language, 't', $self->to_selector );

    # nodes that are aligned
    my %is_aligned;

    # delete previously made links
    foreach my $tnode ( $troot->get_descendants ) {
        $tnode->set_attr( 'alignment', [] );
    }

    # precompute links from a-nodes to t-nodes
    my %a2t;
    foreach my $to_tnode ( $to_troot->get_descendants ) {
        my $to_anode = $to_tnode->get_lex_anode;
        next if not $to_anode;
        $a2t{$to_anode} = $to_tnode;
    }

    # copy links from a-layer
    foreach my $tnode ( $troot->get_descendants ) {
        my $anode = $tnode->get_lex_anode;
        next if not $anode;
        my ( $nodes, $types ) = $anode->get_directed_aligned_nodes();
        foreach my $i ( 0 .. $#$nodes ) {
            my $to_tnode = $a2t{ $$nodes[$i] } || next;

            # copy only intersection links
            if ( $$types[$i] =~ /int/ ) {
                $tnode->add_aligned_node( $to_tnode, 'int.gdfa' );
                $is_aligned{$tnode}    = 1;
                $is_aligned{$to_tnode} = 1;
            }
        }
    }
    foreach my $tnode ( $troot->get_descendants ) {
        my $anode = $tnode->get_lex_anode;
        next if not $anode;
        my ( $nodes, $types ) = $anode->get_directed_aligned_nodes();
        foreach my $i ( 0 .. $#$nodes ) {
            my $to_tnode = $a2t{ $$nodes[$i] } || next;

            # copy gdfa links that connect two not yet aligned nodes
            if ( $$types[$i] =~ /gdfa/ && !$is_aligned{$tnode} && !$is_aligned{$to_tnode} ) {
                $tnode->add_aligned_node( $to_tnode, 'gdfa' );
                $is_aligned{$tnode}    = 1;
                $is_aligned{$to_tnode} = 1;
            }
        }
    }
    
    # connect other not yet aligned nodes, that have the same functor and their parents are aligned
    foreach my $tnode ( $troot->get_descendants ) {
        next if $is_aligned{$tnode};
        my ( $nodes, $types ) = $tnode->get_parent->get_directed_aligned_nodes();
        next if !$nodes || !@$nodes;
        next if !$is_aligned{ $$nodes[0] };
        foreach my $candidate ( $$nodes[0]->get_children() ) {
            if ( !$is_aligned{$candidate} && $candidate->functor eq $tnode->functor ) {
                $tnode->add_aligned_node( $candidate, 'rule-based' );
                $is_aligned{$tnode}     = 1;
                $is_aligned{$candidate} = 1;
                last;
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::T::PCEDTAlignment

=head1 DESCRIPTION

This block copies all alignment connections of type 'int' from a-layer to t-layer using lex.rf links.
Then it connect some remaining (not yet aligned) nodes that have the same functor and their parents are connected.
Alignment connections copied from a-layer ar labeled 'giza++', the other are labeled 'rule-based'.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
