package Treex::Scen::Analysis::CS;
use Moose;
use Treex::Core::Common;

# Note that scenarios can be parametrized.
# Usage is simple:
# treex Read::Sentences Scen::Analysis::CS memory=autodetect ner=0 Write::Treex

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
#     documentation => 'Do Named Entity Recognition (using A2N::CS::NameTag)',
# );

# TODO Add smart sentence segmenter
# which will do nothing if the text is already segmented.
# Perhaps add W2A::CS::Segment if_segmented=skip.
# This way we could use both
# treex Read::Sentences Scen::Analysis::CS
# treex Read::Text Scen::Analysis::CS

my $FULL = <<'END';
# m-layer
W2A::CS::Tokenize
W2A::CS::TagMorphoDiTa lemmatize=1
W2A::CS::FixMorphoErrors

# n-layer
A2N::CS::NameTag
A2N::CS::NormalizeNames

# a-layer
W2A::CS::ParseMSTAdapted
W2A::CS::FixAtreeAfterMcD
W2A::CS::FixIsMember
W2A::CS::FixPrepositionalCase
W2A::CS::FixReflexiveTantum
W2A::CS::FixReflexivePronouns

# t-layer
A2T::CS::MarkEdgesToCollapse expletives=0
A2T::BuildTtree
A2T::RehangUnaryCoordConj
A2T::SetIsMember
A2T::CS::SetCoapFunctors
A2T::FixIsMember
A2T::MarkParentheses
A2T::MoveAuxFromCoordToMembers
A2T::CS::MarkClauseHeads
A2T::CS::MarkRelClauseHeads
A2T::CS::MarkRelClauseCoref
#A2T::DeleteChildlessPunctuation We want quotes as t-nodes
A2T::CS::FixTlemmas
A2T::CS::FixNumerals
A2T::SetNodetype
A2T::CS::SetFormeme use_version=2 fix_prep=0
A2T::CS::SetDiathesis
A2T::CS::SetFunctors memory=2g

# There are some problems with ML-Process, so let's skip it
#A2T::CS::SetFunctors
#A2T::SetNodetype
A2T::CS::SetMissingFunctors
A2T::SetNodetype

A2T::FixAtomicNodes
A2T::CS::SetGrammatemes
A2T::SetSentmod
A2T::CS::MarkReflexivePassiveGen
A2T::CS::FixNonthirdPersSubj
A2T::CS::AddPersPron
T2T::SetClauseNumber
A2T::CS::MarkReflpronCoref
A2T::SetDocOrds
A2T::CS::MarkTextPronCoref
Coref::RearrangeLinks retain_cataphora=1

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::CS - Czech tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Len Read::Sentences from=my.txt Scen::Analysis::CS Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::CS

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging+lemmatization (MorphoDiTa), NER (NameTag),
dependency parsing (MST) and tectogrammatical analysis.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
