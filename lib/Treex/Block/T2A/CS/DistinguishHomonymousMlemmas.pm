package TCzechT_to_TCzechA::Distinguish_homonymous_mlemmas;

use strict;
use warnings;
use List::MoreUtils qw( any all );

use base qw(TectoMT::Block);

use utf8;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $tnode ( $bundle->get_tree('TCzechT')->get_descendants ) {

        if ($tnode->get_attr('t_lemma') =~ /^stát(_se)?$/
                and $tnode->get_attr('mlayer_pos') eq "V") {

            my $anode = $tnode->get_lex_anode;
            my $src_tnode = $tnode->get_source_tnode;

            my $index;
            my $source_tlemma =  $src_tnode->get_attr('t_lemma');

            if ($source_tlemma =~ /^(happen|become|get|grow|be)$/) {
                $index = 2;
            }
            elsif ($source_tlemma =~ /^(stand|move|stop|go|insist)$/) {
                $index = 3;
            }
            else  { # nejcastejsi: cost
                $index = 4;
            }

            $anode->set_attr('m/lemma', $anode->get_attr('m/lemma')."-$index");

        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Distinguish_homonymous_mlemmas

Adding numerical suffices to morphological lemmas, in order
to distinguish homonyms with different infleciton (such as stát-1).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
