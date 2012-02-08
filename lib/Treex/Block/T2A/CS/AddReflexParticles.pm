package Treex::Block::T2A::CS::AddReflexParticles;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $reflexive;
    my $afun;

    if ( $t_node->t_lemma =~ /_(s[ie])$/ ) {
        $reflexive = $1;
        $afun      = 'AuxT';
    }
    elsif ( ( $t_node->voice || $t_node->gram_diathesis || '' ) =~ m/^(reflexive_diathesis|deagent)$/ ) {
        $reflexive = 'se';
        $afun      = 'AuxR';
    }
    else {
        return;
    }

    my $a_node    = $t_node->get_lex_anode();
    my $refl_node = $a_node->create_child();
    $refl_node->reset_morphcat();
    $refl_node->set_form($reflexive);
    $refl_node->set_lemma($reflexive);
    $refl_node->set_afun($afun);
    $refl_node->set_attr( 'morphcat/pos',    'P' );
    $refl_node->set_attr( 'morphcat/subpos', '7' );
    $refl_node->set_attr( 'morphcat/number', 'X' );
    $refl_node->set_attr( 'morphcat/case',   $reflexive eq 'si' ? 3 : 4 );
    $refl_node->wild->{lex_verb_child} = ( $afun eq 'AuxT' ? 1 : 0 );

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
