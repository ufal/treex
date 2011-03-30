package Treex::Block::T2A::CS::AddReflexParticles;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $reflexive;
    if ( $t_node->t_lemma =~ /_(s[ie])$/ ) {
        $reflexive = $1;
    }
    elsif ( ( $t_node->voice || '' ) eq 'reflexive_diathesis' ) {
        $reflexive = 'se';
    }
    else {
        return;
    }

    my $a_node    = $t_node->get_lex_anode();
    my $refl_node = $a_node->create_child();
    $refl_node->reset_morphcat();
    $refl_node->set_form($reflexive);
    $refl_node->set_lemma($reflexive);
    $refl_node->set_afun('AuxT');
    $refl_node->set_attr( 'morphcat/pos',    'P' );
    $refl_node->set_attr( 'morphcat/subpos', '7' );
    $refl_node->set_attr( 'morphcat/number', 'X' );
    $refl_node->set_attr( 'morphcat/case',   $reflexive eq 'si' ? 3 : 4 );

    $t_node->add_aux_anodes($refl_node);

    # Correct position will be found later (Move_clitics_to_wackernagel),
    # but some ord must be filled now (place it just after the verb).
    $refl_node->shift_after_node($a_node);
    return;
}

1;

=over

=item Treex::Block::T2A::CS::AddReflexParticles

For reflexive tantum verbs (_si or _se in their tlemma),
create new a-nodes corresponding to reflexive particles/pronouns.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
