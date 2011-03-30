package Treex::Block::T2A::CS::AddAuxVerbConditional;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

my %condit_numberperson2form = (
    'S1' => 'bych',
    'S2' => 'bys',
    'P1' => 'bychom',
    'P2' => 'byste',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # We want to process only conditionals that don't have
    # 'conditional conjunctions' "aby", "kdyby" in the formeme.
    my $verbmod = $t_node->get_attr('gram/verbmod') || '';
    return if $verbmod ne 'cdn';
    return if $t_node->formeme =~ /(aby|kdyby)/;

    my $a_node   = $t_node->get_lex_anode();
    my $new_node = $a_node->create_child(
        {   'lemma'           => 'být',
            'afun'            => 'AuxV',
            'morphcat/pos'    => 'V',
            'morphcat/subpos' =>, 'c',
        }
    );

    my $person = $a_node->get_attr('morphcat/person')           || '';
    my $number = $a_node->get_attr('morphcat/number')           || '';
    my $form   = $condit_numberperson2form{ $number . $person } || 'by';
    $new_node->set_form($form);
    $t_node->add_aux_anodes($new_node);
    $new_node->shift_before_node($a_node);

    #TODO set a_node tense to past?
    $a_node->set_attr( 'morphcat/subpos', 'p' );
    return;
}

1;

=over

=item Treex::Block::T2A::CS::AddAuxVerbConditional

Add auxiliaries such as by/bys/bychom... expressing conditional verbmod.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
