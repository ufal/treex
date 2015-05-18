package Treex::Block::T2T::CS2CS::ParaphraseSimple;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::ParaphraseSimple';
use autodie;

sub postprocess_changed_node {
    my ($self, $tnode) = @_;

    # nouns may have different gender
    if ( defined $tnode->gram_sempos && $tnode->gram_sempos =~ /^n\.denot/) {
        $tnode->set_gram_gender(undef);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::ParaphraseSimple - change lemmas in references to resemble MT-output

=head1 USAGE

 Util::SetGlobal language=cs
 
 Read::AlignedSentences cs_=ref.txt cs_mt=mt.txt
 Util::SetGlobal selector=
 Scen::Analysis::CS
 Util::SetGlobal selector=mt
 Scen::Analysis::CS
 
 Util::SetGlobal selector=gen 
 T2T::CopyTtree source_selector= 
 T2T::ParaphraseSimple paraphrases_file='my/file.tsv' mt_selector=tectomt selector=reference language=cs
 Scen::Synthesis::CS
 Align::A::MonolingualGreedy to_selector=
 T2T::CS2CS::ProjectChangedToA 
 
 Util::SetGlobal selector=
 A2A::CS::VocalizePreposPlain
 T2A::CS::CapitalizeSentStart
 A2W::CS::Detokenize
 Write::Sentences

=head1 DESCRIPTION

Input: t-trees of reference translation and machine translation
Input: file with single-lemma paraphrases (synonyms),
in the format:
t_lemma1[tab]t_lemma2
(we assume symmetry, i.e. each entry allows paraphrasing each of the two lemmas
with the other one).
Output: modified reference translation t-tree

For each t_lemma that appears in reference but does not appear in MT,
we try to find a t_lemma that appears in the MT but not in reference
and that is an allowed paraphrase of the original t_lemma
as specified by the paraphrase file.
If we find such a t_lemma, we set it as the new t_lemma;
if the lexnode is a noun, we also undefine the gender grammateme
(to be filled later by AddNounGender block).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
