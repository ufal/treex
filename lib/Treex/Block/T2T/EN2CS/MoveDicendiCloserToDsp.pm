package Treex::Block::T2T::EN2CS::MoveDicendiCloserToDsp;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;

sub process_tnode {
    my ( $self, $t_node ) = @_;
    return if !Treex::Tool::Lexicon::CS::is_dicendi_verb( $t_node->t_lemma );
    my @children = $t_node->get_children( { ordered => 1 } );

    my ($speech_root) = reverse grep { $_->formeme eq 'v:fin' } @children;
    return if !$speech_root || $t_node->precedes($speech_root);

    # 1. Direct speech (with quotes)
    # Shift dicendi verb just after the closing quote node.
    # Quotes are usually hanged on the dicendi verb, not on the $speech_root.
    my ($quot) = reverse grep { $_->t_lemma =~ /[“"]/ } @children;
    if ( $quot && $quot->precedes($t_node) ) {
        $t_node->shift_after_node( $quot, { without_children => 1 } );
    }

    # 2. Indirect speech (no quotes)
    # Shift dicendi verb just after the speech subtree.
    else {
        $t_node->shift_after_subtree( $speech_root, { without_children => 1 } );
    }
    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::MoveDicendiCloserToDsp

Move I<verba dicendi> following a speech (both direct and indirect)
just after the last token of the speech clause.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, Martin Popel, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
