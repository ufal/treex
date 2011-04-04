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
    
    # copy links form a-layer
    foreach my $tnode ( $troot->get_descendants ) {
        my $anode = $tnode->get_lex_anode;
        next if not $anode;
        my ( $nodes, $types ) = $anode->get_aligned_nodes();
        foreach my $i ( 0 .. $#$nodes ) {
            my $to_tnode = $a2t{ $$nodes[$i] } || next;
            # copy only 'intersection' links
            if ($$types[$i] =~ /int/) {
                $tnode->add_aligned_node( $to_tnode, 'giza++' );
                $is_aligned{$tnode} = 1;
                $is_aligned{$to_tnode} = 1;
            }
        }
    }

    # connect generated nodes
    foreach my $tnode ( $troot->get_descendants ) {
        next if $is_aligned{$tnode};
        next if $tnode->t_lemma !~ /^#(NewNode|Gen|PersPron)$/;
        my ($nodes, $types) = $tnode->get_parent->get_aligned_nodes();
        next if !@$nodes;
        next if !$is_aligned{$$nodes[0]};
        foreach my $candidate ( $$nodes[0]->get_children() ) {
            if ($candidate->functor eq $tnode->functor) {
                $tnode->add_aligned_node( $candidate, 'rule-based' );
                last;
            }
        }
    }
}

1;

=over

=item Treex::Block::Align::T::CopyAlignmentFromAlayer;

PARAMETERS:

- language - language in which the alignment attributes are included

- to_language - the other language

=back

=cut

# Copyright 2009-2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
