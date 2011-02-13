package TCzechT_to_TCzechA::Add_reflex_particles;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $t_node ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        process_tnode($t_node);
    }
    return;
}

sub process_tnode {
    my ($t_node) = @_;
    my $reflexive;
    if ( $t_node->get_attr('t_lemma') =~ /_(s[ie])$/ ) {
        $reflexive = $1;
    }
    elsif ( ( $t_node->get_attr('voice') || '' ) eq 'reflexive_diathesis' ) {
        $reflexive = 'se';
    }
    else {
        return;
    }

    my $a_node    = $t_node->get_lex_anode();
    my $refl_node = $a_node->create_child();
    $refl_node->reset_morphcat();
    $refl_node->set_attr( 'm/form',          $reflexive );
    $refl_node->set_attr( 'm/lemma',         $reflexive );
    $refl_node->set_attr( 'afun',            'AuxT' );
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

=item TCzechT_to_TCzechA::Add_reflex_particles

For reflexive tantum verbs (_si or _se in their tlemma),
create new a-nodes corresponding to reflexive particles/pronouns.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
