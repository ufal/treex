package Treex::Block::T2A::RU::AddNegation;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if ( ( $tnode->gram_negation || '' ) eq 'neg1' && $tnode->gram_sempos eq 'v' ) {
        my $anode    = $tnode->get_lex_anode();
        my $new_node = $anode->create_child();
        $new_node->shift_before_node($anode);

        $new_node->reset_morphcat();
        $new_node->set_lemma('не');
        $new_node->set_form('не');
    }

    return;
}

1;

=over

=item Treex::Block::T2A::RU::AddNegation

Add a new a-node which represents a verbal negation particle ("не").

=back

=cut

# Copyright 2012 Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
