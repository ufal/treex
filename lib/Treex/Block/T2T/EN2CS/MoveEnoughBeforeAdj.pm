package SEnglishT_to_TCzechT::Move_enough_before_adj;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {

    my ( $self, $bundle ) = @_;

    foreach my $tnode ($bundle->get_tree('TCzechT')->get_descendants) {

	if (($tnode->get_attr('t_lemma')||'') eq 'dost'
                and ($tnode->get_parent->get_attr('mlayer_pos')||'') eq 'A'
                    and $tnode->get_parent->precedes($tnode)) {

            $tnode->shift_before_node($tnode->get_parent);

	}
    }
}

1;

=over

=item SEnglishT_to_TCzechT::Move_enough_before_adj

'Enough' t-node adjectives should be moved
in front of them. 'He is big enough' -> 'Je dost velky'.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
