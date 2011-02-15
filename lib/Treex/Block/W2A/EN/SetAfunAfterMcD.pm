package Treex::Block::W2A::EN::SetAfunAfterMcD;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    # Don't change afun, if already filled
    next if defined $anode->afun;

    # Fill afun
    $a_node->set_afun( get_afun($a_node) );

    return 1;
}

# CoNLL_deprel -> afun mapping for Sb, Obj, Adv, Atr
Readonly my %AFUN_FOR => (
    SBJ  => 'Sb',
    OBJ  => 'Obj', IOBJ => 'Obj',
    ADV  => 'Adv', PMOD => 'Adv',
    NMOD => 'Atr',
);

sub get_afun {
    my ($a_node) = @_;

    # 1. solve IN and TO tags (conll_deprell is not much helpful here)
    my $tag = $a_node->tag;
    my $has_verb_child = grep { $_->tag =~ /^V/ } $a_node->get_eff_children();
    if ( $tag eq 'TO' ) {
        return 'AuxV' if $has_verb_child;    # to + infinitive
        return 'AuxP';                       # to + noun
    }
    if ( $tag eq 'IN' ) {
        return 'AuxC' if $has_verb_child;
        return 'AuxP';                       # TODO pozor: AuxP dostanou takhle podr. spojky
    }

    # 2. try CoNLL_deprel -> afun mapping for Sb, Obj, Adv, Atr
    my $conll_deprel = $a_node->conll_deprel;
    my $parent       = $a_node->get_parent();

    # With coordinations, the deprel relevant to members'
    # is saved in the coordination head.
    if ( $conll_deprel eq 'COORD' ) {
        $conll_deprel = $parent->conll_deprel;
    }
    my $afun = $AFUN_FOR{$conll_deprel};
    return $afun if $afun;

    # 3. try some rules
    my ($eparent) = $a_node->get_eff_parents();
    my $form = $a_node->form;
    return 'Pred' if $tag =~ /^V/ && $eparent->is_root();
    return 'AuxV' if $tag =~ /^V/
            && !$parent->is_root()
            && $parent->tag =~ /^V/
            && $a_node->precedes($parent);
    return 'AuxK' if $form eq '.';    # !!! zatim vcetne tecek za zkratkami
    return 'AuxX' if $form eq ',';

    my $eparent_tag = $eparent->tag || '_root';
    if ( $tag =~ /^(NN|PRP|CD$|WP$|WDT$)/ && $eparent_tag =~ /^V/ ) {
        return 'Sb' if $a_node->precedes($eparent);
        return 'Obj';
    }

    # 4. Special value for not recognized afun
    return 'NR';
}

1;

__END__

=over

=item Treex::Block::W2A::EN::SetAfunAfterMcD

Fill the afun attribute by several heuristic rules
using especially tag and conll_deprel attributes.
This block doesn't change already filled afun values
e.g. with C<SEnglishM_to_SEnglishA::Fix_multiword_prep_and_conj>.

=back

=cut

# Copyright 2009 Zdenek Zabokrtsky, Jana Kravalova, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
