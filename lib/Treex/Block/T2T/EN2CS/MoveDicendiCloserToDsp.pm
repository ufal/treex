package SEnglishT_to_TCzechT::Move_dicendi_closer_to_dsp;

use utf8;
use 5.008;
use strict;
use warnings;
use Report;
use Lexicon::Czech;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $t_node ( $t_root->get_descendants() ) {
        next if ! Lexicon::Czech::is_dicendi_verb($t_node->get_attr('t_lemma'));
        my @children = $t_node->get_children( { ordered => 1 } );

        my ($speech_root) = reverse grep { $_->get_attr('formeme') eq 'v:fin' } @children;
        next if !$speech_root || $t_node->precedes($speech_root);

        # 1. Direct speech (with quotes)
        # Shift dicendi verb just after the closing quote node.
        # Quotes are usually hanged on the dicendi verb, not on the $speech_root.
        my ($quot) = reverse grep { $_->get_attr('t_lemma') =~ /[“"]/ } @children;
        if ( $quot && $quot->precedes($t_node) ) {
            $t_node->shift_after_node( $quot, { without_children => 1 } );
        }

        # 2. Indirect speech (no quotes)
        # Shift dicendi verb just after the speech subtree.
        else {
            $t_node->shift_after_subtree( $speech_root, { without_children => 1 } );
        }
    }
    return;
}

1;

=over

=item SEnglishT_to_TCzechT::Move_dicendi_closer_to_dsp

Move I<verba dicendi> following a speech (both direct and indirect)
just after the last token of the speech clause.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
