package Treex::Scen::Analysis::EN;
use Moose;
use Treex::Core::Common;

# Note that scenarios can be parametrized.
# Usage is simple:
# treex Read::Sentences Scen::Analysis::EN memory=autodetect ner=0 Write::Treex

# TODO Add parameters e.g.
# has memory => (
#     is => 'ro',
#     isa => enum( [qw(small 1G 2G autodetect)] ),
#     default => '2G',
#     documentation => 'Choose suitable scenario (and model for MST parser) depending on the available memory',
# );
# has ner => (
#     is => 'ro',
#     isa => 'Bool',
#     default => 1,
#     documentation => 'Do Named Entity Recognition (using A2N::EN::NameTag)',
# );

# TODO Add smart sentence segmenter
# which will do nothing if the text is already segmented.
# Perhaps add W2A::EN::Segment if_segmented=skip.
# This way we could use both
# treex Read::Sentences Scen::Analysis::EN
# treex Read::Text Scen::Analysis::EN

my $FULL = <<'END';
W2A::EN::Tokenize
W2A::EN::NormalizeForms
W2A::EN::FixTokenization
W2A::EN::TagMorce
W2A::EN::FixTags
W2A::EN::Lemmatize
A2N::EN::NameTag
A2N::EN::DistinguishPersonalNames
W2A::MarkChunks
W2A::EN::ParseMST model=conll_mcd_order2_0.01.model
W2A::EN::SetIsMemberFromDeprel
W2A::EN::RehangConllToPdtStyle
W2A::EN::FixNominalGroups
W2A::EN::FixIsMember
W2A::EN::FixAtree
W2A::EN::FixMultiwordPrepAndConj
W2A::EN::FixDicendiVerbs
W2A::EN::SetAfunAuxCPCoord
W2A::EN::SetAfun
W2A::FixQuotes
A2A::ConvertTags input_driver=en::penn
A2A::EN::EnhanceInterset
A2T::EN::MarkEdgesToCollapse
A2T::EN::MarkEdgesToCollapseNeg
A2T::BuildTtree
A2T::SetIsMember
A2T::EN::MoveAuxFromCoordToMembers
A2T::EN::FixTlemmas
A2T::EN::SetCoapFunctors
A2T::EN::FixEitherOr
A2T::EN::FixHowPlusAdjective
A2T::FixIsMember
A2T::EN::MarkClauseHeads
A2T::EN::SetFunctors
A2T::EN::MarkInfin
A2T::EN::MarkRelClauseHeads
A2T::EN::MarkRelClauseCoref
A2T::EN::MarkDspRoot
A2T::MarkParentheses
A2T::SetNodetype
A2T::EN::SetFormemeInterset
A2T::EN::SetTense
A2T::EN::SetGrammatemes
A2T::EN::SetSentmod
A2T::EN::RehangSharedAttr
A2T::EN::SetVoice
A2T::EN::FixImperatives
A2T::EN::SetIsNameOfPerson
A2T::EN::SetGenderOfPerson
A2T::EN::AddCorAct
T2T::SetClauseNumber
A2T::EN::FixRelClauseNoRelPron
A2T::EN::MarkReferentialIt resolver_type=nada threshold=0.5 suffix=nada_0.5 # you need Treex::External::NADA installed for this
A2T::EN::FindTextCoref

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::EN - English tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Len Read::Sentences from=my.txt Scen::Analysis::EN Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::EN

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging (Morce), lemmatization, NER (NameTag),
dependency parsing (MST) and tectogrammatical analysis.

Note that Morce tagger cannot be instantiated twice -- therefore,
this scenario cannot be invoked more than once in one call to Treex.
If this is a problem for you, you either have to use separate calls to Treex,
writing out your data to disk and then reading them back between the calls,
or use MorphoDiTa instead of Morce.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
