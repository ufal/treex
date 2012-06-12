package Treex::Block::T2A::RU::AddAuxVerbConditional;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # We want to process only conditionals that don't have
    # 'conditional conjunctions' "aby", "kdyby" in the formeme.
    if ( ( $t_node->gram_verbmod || '' ) eq 'cdn' ) {
        my $a_node   = $t_node->get_lex_anode();
        my $new_node = $a_node->create_child(
            {   'form'            => 'бы',
                'lemma'           => 'бы', #TODO 'быть',
                'afun'            => 'AuxV',
                'morphcat/pos'    => '!',
                'morphcat/subpos' =>, 'c',
            }

        );
        $t_node->add_aux_anodes($new_node);
        $new_node->shift_after_node($a_node);

        #TODO set a_node tense to past?
        #$a_node->set_attr( 'morphcat/subpos', 'p' );
    }

    return;
}

1;

=over

=item Treex::Block::T2A::RU::AddAuxVerbConditional

Add auxiliary "бы" expressing conditional verbmod.

=back

=cut

# Copyright 2012 Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
