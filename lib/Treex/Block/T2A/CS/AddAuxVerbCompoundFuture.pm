package Treex::Block::T2A::CS::AddAuxVerbCompoundFuture;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Process only verbs with future tense (post) and imperfective aspect (proc)
    my $tense = $tnode->gram_tense || '';
    return if $tense ne 'post';

    # Process only verbs with imperfective aspect (proc)
    # (but all modal verbs are imperfective, eventhough the main verb is not:
    #  "Bude moci získat.")
    my $aspect   = $tnode->gram_aspect   || '';
    my $deontmod = $tnode->gram_deontmod || '';
    return if $deontmod eq 'decl' && $aspect ne 'proc';

    # with the exception of few imperfective verbs which form futurum without
    # using auxiliary verbs (they use prefix "po" instead).
    my $anode = $tnode->get_lex_anode();
    my $lemma = $anode->lemma;
    return if $lemma =~ /^(být|jít|jet|nést|běžet|letět|téci|vézt|hrnout|lézt)$/;

    my $number = $anode->get_attr('morphcat/number') || 'S';
    my $person = $anode->get_attr('morphcat/person') || '';

    my $new_node = $anode->create_child();
    $new_node->shift_after_node($anode);
    $new_node->reset_morphcat();
    $new_node->set_lemma( $anode->lemma );
    $new_node->set_form( $anode->form );
    $new_node->set_attr( 'morphcat/pos', 'V' );
    $anode->set_attr( 'morphcat/subpos', 'B' );

    # negace v kazdem pripade zustava jen u funkcniho
    $new_node->set_attr( 'morphcat/negation', 'A' );

    $anode->set_lemma('být');
    $anode->set_attr( 'morphcat/tense', 'F' );
    $anode->set_afun( 'AuxV' );

    $new_node->set_attr( 'morphcat/subpos', 'f' );    # 'bude videt'

    # Passives are already solved in the block Add_auxverb_compound_passive
    # In the choosen implementation $t_node->get_lex_anode() goes to auxiliary
    # verb "být" which has active voice, so next code is now useless.
    #my $voice = $anode->get_attr('morphcat/voice');
    #if ( $voice eq 'P' ) {  # 'bude viden'
    #    warn $anode->id, " passive future\n";
    #    $new_node->set_attr( 'morphcat/subpos', 's' );
    #    $new_node->set_attr( 'morphcat/voice',  'P' );
    #    $new_node->set_attr( 'morphcat/gender', $anode->get_attr('morphcat/gender') );
    #    $new_node->set_attr( 'morphcat/number', $anode->get_attr('morphcat/number') );
    #}

    $anode->set_attr( 'morphcat/gender', '-' );
    $tnode->add_aux_anodes($new_node);

    return;
}

1;

__END__

=encoding utf8

=over

=item Treex::Block::T2A::CS::AddAuxVerbCompoundFuture

Add auxiliaries such as jsem/jste... in past-tense complex
verb forms (viděli jsme, přišli jste).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
