package Treex::Block::A2T::EN::FixImperatives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;


    foreach my $tnode ( grep { $_->gram_sempos eq "v" } $t_root->get_descendants ) {
        my $anode = $tnode->get_lex_anode;

        next if ( $tnode->sentmod || '' ) eq 'inter';
        # technically, imperatives should be VB, not VBP,
        # but the tagger often gets this wrong...
        next if not $anode or $anode->tag !~ /^VBP?$/;
        # ...except for 'be' where forms of VB and VBP are distinct
        next if $anode->lemma eq 'be' and $anode->tag eq 'VBP';
        # rule out expressions with modals and auxiliaries or infinitives 
        next if grep { $_->tag     =~ /^(MD|VB[DZ]|TO)$/ } $tnode->get_aux_anodes; 
        # imperatives do not usually take subordinate conjunctions
        # -- but still from data it seems that they do more often than not
        # next if grep { $_->afun    eq 'AuxC' } $tnode->get_aux_anodes; 
        next if grep { $_->formeme eq "n:subj" } $tnode->get_echildren;

        $tnode->set_gram_verbmod('imp');
        $tnode->set_sentmod('imper');
        $tnode->set_formeme('v:fin');

        my $perspron = $tnode->create_child;
        $perspron->shift_before_node($tnode);

        $perspron->set_is_generated(1);
        
        $perspron->set_t_lemma('#PersPron');
        $perspron->set_functor('ACT');
        $perspron->set_formeme('n:subj');    # !!! elided?
        $perspron->set_nodetype('complex');
        $perspron->set_gram_sempos('n.pron.def.pers');
        $perspron->set_gram_number('pl');    # default: vykani
        $perspron->set_gram_gender('anim');
        $perspron->set_gram_person('2');

    }

    return 1;
}

1;

=over

=item Treex::Block::A2T::EN::FixImperatives

Imperatives are recognized (at least some of), and provided with
a new PersPron node and corrected gram/verbmod value.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
