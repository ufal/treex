package TCzechT_to_TCzechA::Delete_empty_nouns;

use utf8;
use 5.008;
use strict;
use warnings;
use List::MoreUtils qw( any all );
use List::Util qw(first);

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $t_root->get_descendants() ) {

        my @children = $cs_tnode->get_children;

        if (@children == 1
                and $children[0]->get_attr('formeme') eq 'adj:attr'
                    and $children[0]->precedes($cs_tnode)) {

            my $en_tnode = $cs_tnode->get_source_tnode;

            if ($en_tnode->get_attr('t_lemma') eq 'one'
                    and my $a_node = $cs_tnode->get_lex_anode) {

                foreach my $a_child ($a_node->get_children) {
                    $a_child->set_parent($a_node->get_parent);
                }

                $a_node->disconnect;
#                print $bundle->get_attr('english_source_sentence')."\n";
            }
        }
    }
    return;
}

1;

__END__

=over

=item TCzechT_to_TCzechA::Delete_empty_nouns

Delete 'empty nouns' emerging during en->cs transfer
from 'one' in constructions such as 'damaged one'.
(!!! should be moved to the transfer phase, but we don't have
any processing of empty nouns so far)

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
