package SEnglishT_to_TCzechT::Add_PersPron_below_vfin;

use 5.008;
use strict;
use warnings;
use List::MoreUtils qw( any all );
use List::Util qw( first );

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');
    my @all_nodes = $t_root->get_descendants( { ordered => 1 } );

    # When looking for antecedent we need all nouns (as candidates) in reversed order
    my @nouns = reverse grep { ( $_->get_attr('gram/sempos') || '' ) =~ /^n/ } @all_nodes;

    VFIN:
    foreach my $vfin_tnode ( grep { $_->get_attr('formeme') =~ /fin|rc/ } @all_nodes ) {

        # Skip verbs with subject (i.e. child in nominative)
        next VFIN if any { $_->get_attr('formeme') =~ /1/ } $vfin_tnode->get_eff_children();

        # Find antecedent by heuristics: nearest noun left to the $vfin_tnode
        my $antec = first { $_->precedes($vfin_tnode) } @nouns;
        next VFIN if !$antec;

        # Create new t-node
        my $perspron = $vfin_tnode->create_child(
            {   attributes => {
                    nodetype       => 'complex',
                    functor        => '???',
                    formeme        => 'n:1',
                    t_lemma        => '#PersPron',
                    t_lemma_origin => 'Add_PersPron_below_vfin',
                    mlayer_pos     => 'P',
                    'gram/sempos'  => 'n.pron.def.pers',
                    'gram/person'  => $antec->get_attr('gram/person') || 3,
                    }
            }
        );
        foreach my $attr_name ( 'gram/gender', 'gram/number' ) {
            $perspron->set_attr( $attr_name, $antec->get_attr($attr_name) );
        }
        $perspron->shift_before_node($vfin_tnode);

    }
    return;
}

1;

=over

=item SEnglishT_to_TCzechT::Add_PersPron_below_vfin

New #PersPron node is added below all finite verbs
which have none (they might have been created from an infinitive),
and its gender and number is copied from the nearest left
semantic noun (very rough coreference heuristics).

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
