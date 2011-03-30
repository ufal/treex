package Treex::Block::A2T::CS::MarkEdgesToCollapse;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';
use utf8;

sub process_anode {
    my ( $self, $a_node ) = @_;

    my $parent = $a_node->get_parent();

    # default values
    $a_node->set_edge_to_collapse(0);
    $a_node->set_is_auxiliary(0);

    # No node (except AuxK = terminal punctuation: ".?!")
    # can collapse to a technical root.
    if ( $parent->is_root() ) {
        if ( $a_node->afun eq 'AuxK' ) {
            $a_node->set_edge_to_collapse(1);
            $a_node->set_is_auxiliary(1);
        }
    }

    # Should collapse to parent because the $node is auxiliary?
    elsif ( is_aux_to_parent($a_node) ) {
        $a_node->set_edge_to_collapse(1);
        $a_node->set_is_auxiliary(1);
    }

    # Should collapse to parent because the $parent is auxiliary?
    elsif ( is_parent_aux_to_me($a_node) ) {
        $a_node->set_edge_to_collapse(1);
        $parent->set_is_auxiliary(1);
    }

    # Some a-nodes don't belong to any of the t-nodes
    if ( is_aux_to_nothing($a_node) ) {
        $a_node->set_edge_to_collapse(0);
        $a_node->set_is_auxiliary(1);
    }
    return;
}

sub is_aux_to_parent {
    my ($a_node) = shift;
    return (
        ( $a_node->tag =~ /^Z/ and $a_node->afun !~ /Coord|Apos/ ) ||
            ( $a_node->afun  eq "AuxV" ) ||
            ( $a_node->afun  eq "AuxT" ) ||
            ( $a_node->lemma eq "jako" and $a_node->afun !~ /AuxC/ ) ||
            ( $a_node->afun  eq "AuxP" and $a_node->get_parent->afun eq "AuxP" )
    );
}

sub is_parent_aux_to_me ($) {
    my ($a_node) = shift;

    my $a_parent = $a_node->get_parent();
    return 0 if !$a_parent;

    return (
        (   $a_node->tag =~ /^Vf/
                && $a_node->afun ne 'Sb'
                &&
                $a_parent->lemma =~ /^(m[í]t|cht[í]t|muset|moci|sm[ě].t)(\_.*)?$/
        )
            ||
            ( $a_node->tag =~ /^Vs/ && $a_parent->lemma =~ /^(b[ý]t)(\_.*)?$/ ) ||
            ( $a_parent->afun =~ /Aux[PC]/ && $a_node->afun !~ /^Aux[YZ]$/ ) ||
            ( lc( $a_parent->form ) eq "jako" && $a_parent->afun eq "AuxY" )
    );
}

sub is_aux_to_nothing ($) {
    my ($a_node) = shift;

    return (
        ( !$a_node->get_children() ) &&
            ( $a_node->afun eq 'AuxX' )
    );
}

1;

=over

=item Treex::Block::A2T::CS::MarkEdgesToCollapse

Before applying this block, afun values Aux[ACKPVX] and Coord must be filled.

=back

=cut

# Copyright 2009-2011 Martin Popel, Zdenek Zabokrtsky, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
