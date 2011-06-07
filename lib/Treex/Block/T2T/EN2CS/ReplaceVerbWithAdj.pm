package Treex::Block::T2T::EN2CS::ReplaceVerbWithAdj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tools::Lexicon::Derivations::CS;

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if (( $tnode->formeme || "" ) eq 'v:fin'
        && $tnode->precedes( $tnode->get_parent )
        && $tnode->src_tnode and ( $tnode->src_tnode->formeme || '' ) =~ /v:(attr|ger)/
        && ( $tnode->get_parent->formeme || '' ) =~ /^n/
        )
    {

        my ( $short_verb_lemma, $suffix ) = split /_/, $tnode->t_lemma;

        my ($adj_lemma) = map { Treex::Tools::Lexicon::Derivations::CS::verb2activeadj($_) }
            (
            $short_verb_lemma,
            Treex::Tools::Lexicon::Derivations::CS::perf2imperf($short_verb_lemma),
            Treex::Tools::Lexicon::Derivations::CS::imperf2perf($short_verb_lemma),
            );

        if ($adj_lemma) {
            if ($suffix) {
                $adj_lemma .= "_$suffix";
            }
            $tnode->set_t_lemma($adj_lemma);
            $tnode->set_gram_sempos('adj.denot');
            $tnode->set_gram_degcmp('pos');
            $tnode->set_attr( 'formeme',     'adj:attr' );
            $tnode->set_attr( 'mlayer_pos',  'A' );
        }
    }
}

1;

=over

=item Treex::Block::T2T::EN2CS::ReplaceVerbWithAdj

Finite verbs in attributive positions, originating from -ing or passive verb forms
in attributive positions, are turned to derived adjectives.

It would be much better to move all this stuff into the translation model/dictionary!!!

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
