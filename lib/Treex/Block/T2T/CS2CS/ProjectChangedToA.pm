package Treex::Block::T2T::CS2CS::ProjectChangedToA;
use Moose;
extends 'Treex::Block::T2T::ProjectChangedToA';
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;
use utf8;

sub is_punct {
    my ($self, $anode) = @_;

    return ($anode->tag =~ /^Z/);
}

sub tag_defined {
    my ($self, $anode) = @_;

    return ($anode->tag !~ /^X@/);
}

sub lemmas_eq {
    my ($self, $anode1, $anode2) = @_;

    # The lemmas come in various styles, so I trim them all.
    return ( Treex::Tool::Lexicon::CS::truncate_lemma($anode1->lemma, 1)
          eq Treex::Tool::Lexicon::CS::truncate_lemma($anode2->lemma, 1) );
}

sub tags_eq {
    my ($self, $anode1, $anode2) = @_;

    # I get sometimes 15-letter tags (PDT)
    # and sometimes 16-letter tags (ČNK, 16th position = aspect).
    return ( substr($anode1->tag, 0, 15) eq substr($anode2->tag, 0, 15) );
}

1;

=pod

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2CS::ProjectChangedToA
-- project only necessary changes to the original a-tree from the generated a-tree,
based on tnode->wild->{changed} attribute.

=head1 SYNOPSIS

 # analyze
 Scen::Analysis::CS
 
 # futurize
 Util::SetGlobal selector=gen
 T2T::CopyTtree source_selector=
 Util::Eval tnode='if (defined $tnode->gram_tense && $tnode->gram_tense ne "post") { $tnode->set_gram_tense("post"); $tnode->wild->{changed}=1; }'
 
 # synthetize
 Scen::Synthesis::CS

 # project changes
 Align::A::MonolingualGreedy to_selector=
 T2T::CS2CS::ProjectChangedToA

 # final polishing
 Util::SetGlobal selector=
 Util::Eval anode='$anode->set_no_space_after("0");'
 A2A::CS::VocalizePreposPlain
 T2A::CS::CapitalizeSentStart
 A2W::Detokenize
 A2W::CS::ApplySubstitutions
 A2W::CS::DetokenizeUsingRules
 A2W::CS::RemoveRepeatedTokens

=head1 DESCRIPTION

This block is useful for the penultimate step in the following scenario (also shown in synopsis):

=over

=item analyze sentence to a-layer and t-layer (src)

=item copy the t-tree

=item do some changes to the t-tree, mark places of change with tnode->wild->{changed}=1

=item generate a-tree

=item copy parts of the generated a-tree into the src a-tree, but only for nodes that correspond to a changed t-node (if there are some changes to the anodes, proceed to the parent and child tnodes so that changes in morphological agreement are propagated)

=item finalize the sentences

=back

TODO: word order is not really handled much.
Generated nodes are put on the left or right side accordingly,
but changes to word order are ignored (actually mostly on purpose).
Especially if the original lex anode becomes something else
(common because auxiliary verbs are lex nodes),
the word order can get quite mixed up.

=head1 PARAMETERS

=over

=item alignment_type

The type of alignment to find source nodes for generated anodes.
Default is C<monolingual>, which is also the default for
L<Treex::Block::Align::A::MonolingualGreedy>.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

