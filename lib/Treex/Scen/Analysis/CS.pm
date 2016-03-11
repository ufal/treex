package Treex::Scen::Analysis::CS;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has tagger => (
     is => 'ro',
     isa => enum( [qw(MorphoDiTa Featurama Morce)] ),
     default => 'MorphoDiTa',
     documentation => 'Which PoS tagger to use',
);

has ner => (
     is => 'ro',
     isa => enum( [qw(NameTag simple none)] ),
     default => 'NameTag',
     documentation => 'Which Named Entity Recognizer to use',
);

has functors => (
     is => 'ro',
     isa => enum( [qw(MLProcess simple VW)] ),
     default => 'MLProcess',
     documentation => 'Which analyzer of functors to use',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
     documentation => 'Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo, default=0',
);

# TODO gazetteers should work without any dependance on target language
has trg_lang => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Gazetteers are defined for language pairs. Both source and target languages must be specified.',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'W2A::CS::Tokenize',
    $self->gazetteer && defined $self->trg_lang ? 'W2A::GazeteerMatch trg_lang='.$self->trg_lang.' filter_id_prefixes="'.$self->gazetteer.'"' : (),
    $self->tagger eq 'MorphoDiTa' ? 'W2A::CS::TagMorphoDiTa lemmatize=1' : (),
    $self->tagger eq 'Featurama'  ? 'W2A::CS::TagFeaturama lemmatize=1' : (),
    $self->tagger eq 'Morce'      ? 'W2A::CS::TagMorce lemmatize=1' : (),
    'W2A::CS::FixMorphoErrors',

    'W2A::CS::FixGuessedLemmas', ###############

    # n-layer
    $self->ner eq 'NameTag' ? 'A2N::CS::NameTag' : (),
    $self->ner eq 'simple' ? 'A2N::CS::SimpleRuleNER' : (),
    $self->domain eq 'IT' ? 'A2N::CS::FixNERforIT' : (),
    'A2N::CS::NormalizeNames',

    # a-layer
    'W2A::CS::ParseMSTAdapted',
    'W2A::CS::FixAtreeAfterMcD',
    'W2A::CS::FixIsMember',
    'W2A::CS::FixPrepositionalCase',
    'W2A::CS::FixReflexiveTantum',
    'W2A::CS::FixReflexivePronouns',

    # t-layer
    'A2T::CS::MarkEdgesToCollapse', ####expletives=0
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::CS::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::MarkParentheses',
    'A2T::MoveAuxFromCoordToMembers',
    'A2T::CS::MarkClauseHeads',
    'A2T::CS::MarkRelClauseHeads',
    'A2T::CS::MarkRelClauseCoref',
    #A2T::DeleteChildlessPunctuation We want quotes as t-nodes
    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::CS::FixTlemmas',
    'A2T::CS::FixNumerals',
    'A2T::SetNodetype',
    'A2T::CS::SetFormeme use_version=2 fix_prep=0',
    'A2T::CS::SetDiathesis',
    $self->functors eq 'MLProcess' ? 'A2T::CS::SetFunctors memory=2g' : (),
    $self->functors eq 'VW' ? 'A2T::CS::SetFunctorsVW' : (),
    $self->functors ne 'VW' ? 'A2T::CS::SetMissingFunctors': (),
    'A2T::SetNodetype',
    'A2T::FixAtomicNodes',
    'A2T::CS::SetGrammatemes',
    'A2T::SetSentmod',
    'A2T::CS::MarkReflexivePassiveGen',
    'A2T::CS::FixNonthirdPersSubj',
    'A2T::CS::AddPersPron',
    'T2T::SetClauseNumber',
    'A2T::CS::MarkReflpronCoref',
    'A2T::SetDocOrds',
    'Coref::CS::SetMultiGender',
    'A2T::CS::MarkTextPronCoref',
    'Coref::RearrangeLinks retain_cataphora=1',
    'Coref::DisambiguateGrammatemes',
    ;

    return $scen;
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

TODO

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
