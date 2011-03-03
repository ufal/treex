package SCzechA_to_SCzechT::Mark_edges_to_collapse;

use utf8;
use 5.008;
use strict;
use warnings;
use Readonly;
use List::MoreUtils qw( any all );
use List::Util qw( first);

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    foreach my $node ( $bundle->get_tree('SCzechA')->get_descendants() ) {
        my $parent = $node->get_parent();

        # default values
        $node->set_attr( 'edge_to_collapse', 0);
        $node->set_attr( 'is_auxiliary', 0);

        # No node (except AuxK = terminal punctuation: ".?!")
        # can collapse to a technical root.
        if ( $parent->is_root() ) {
            if ( $node->get_attr('afun') eq 'AuxK' ) {
                $node->set_attr( 'edge_to_collapse', 1 );
                $node->set_attr( 'is_auxiliary',     1 );
            }
        }

        # Should collapse to parent because the $node is auxiliary?
        elsif ( is_aux_to_parent($node) ) {
            $node->set_attr( 'edge_to_collapse', 1 );
            $node->set_attr( 'is_auxiliary',     1 );
        }

        # Should collapse to parent because the $parent is auxiliary?
        elsif ( is_parent_aux_to_me($node) ) {
            $node->set_attr( 'edge_to_collapse', 1 );
            $parent->set_attr( 'is_auxiliary', 1 );
        }

        # Some a-nodes don't belong to any of the t-nodes
        if ( is_aux_to_nothing($node) ) {
            $node->set_attr( 'edge_to_collapse', 0);
            $node->set_attr( 'is_auxiliary', 1);
        }
    }
    return;
}


sub is_aux_to_parent($) {
    my ($a_node) = shift;
    my $tag      = $a_node->get_attr('m/tag');
    my $afun     = $a_node->get_attr('afun');
    my $lemma    = $a_node->get_attr('m/lemma');
    my $parent   = $a_node->get_parent();
    return (
        ( $tag =~ /^Z/ and $afun !~ /Coord|Apos/ ) ||
        ( $afun eq "AuxV" ) ||
        ( $afun eq "AuxT" ) ||
        ( $lemma eq "jako" and $afun !~ /AuxC/ ) ||
        ( $afun eq "AuxP" and $parent->get_attr('afun') eq "AuxP" )
    );
}


sub is_parent_aux_to_me ($) {
    my ($a_node) = shift;

    my $a_parent = $a_node->get_parent();
    return 0 if !$a_parent;

    return (
        ( $a_node->get_attr('m/tag') =~ /^Vf/ && $a_node->get_attr('afun') ne 'Sb' &&
            $a_parent->get_attr('m/lemma') =~ /^(m[í]t|cht[í]t|muset|moci|sm[ě].t)(\_.*)?$/ ) ||
        ( $a_node->get_attr('m/tag') =~ /^Vs/ && $a_parent->get_attr('m/lemma') =~ /^(b[ý]t)(\_.*)?$/ ) ||
        ( $a_parent->get_attr('afun') =~ /Aux[PC]/ && $a_node->get_attr('afun') !~ /^Aux[YZ]$/ ) ||
        ( lc($a_parent->get_attr('m/form')) eq "jako" && $a_parent->get_attr('afun') eq "AuxY" )
    );
}


sub is_aux_to_nothing ($) {
    my ($a_node) = shift;

    return (
        ( !$a_node->get_children() ) &&
        ( $a_node->get_attr('afun') eq 'AuxX' )
    );
}

1;

=over

=item SCzechA_to_SCzechT::Mark_edges_to_collapse

Before applying this block, afun values Aux[ACKPVX] and Coord must be filled.

=back

=cut

# Copyright 2009-2010 Martin Popel, Zdenek Zabokrtsky, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
