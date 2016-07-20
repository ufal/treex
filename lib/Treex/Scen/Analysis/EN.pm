package Treex::Scen::Analysis::EN;
use Moose;
use Treex::Core::Common;

## main parameters

has tokenizer => (
    is => 'ro',
    isa => enum( [qw(default whitespace none)] ),
    default => 'default',
);

has tagger => (
     is => 'ro',
     isa => enum( [qw(Morce MorphoDiTa)] ),
     default => 'Morce',
     documentation => 'Which PoS tagger to use',
);

has ner => (
     is => 'ro',
     isa => enum( [qw(NameTag Stanford none)] ),
     default => 'NameTag',
     documentation => 'Which Named Entity Recognizer to use',
);

has parser => (
     is => 'ro',
     isa => enum( [qw(MST none)] ),
     default => 'MST',
     documentation => 'Which dependency parser to use',
);

has tecto => (
     is => 'ro',
     isa => enum( [qw(default none)] ),
     default => 'default',
     documentation => 'Which tectogrammatical analysis to use',
);

## parameters for detailed tuning of the scenario

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has functors => (
     is => 'ro',
     isa => enum( [qw(simple MLProcess VW)] ),
     default => 'simple',
     documentation => 'Which analyzer of functors to use',
);

has coref => (
    is => 'ro',
    isa => enum( [qw(simple BART)] ),
    default => 'simple',
    documentation => 'Which coreference resolver to use',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo, default=0',
);

# TODO gazetteers should work without any dependance on target language
has trg_lang => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Gazetteers are defined for language pairs. Both source and target languages must be specified.',
);

has valframes => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Set valency frame references to valency dictionary?',
);

# Useful if you dont have NADA
# Or install NADA:
# cd $TMT_ROOT/install/tool_installation/NADA && perl Makefile.PL && make && make install
has mark_it => ( is => 'rw', isa => 'Bool', default => 1 );

# TODO Add parameter
# has memory => (
#     is => 'ro',
#     isa => enum( [qw(small 1G 2G autodetect)] ),
#     default => '2G',
#     documentation => 'Choose suitable scenario (and model for MST parser) depending on the available memory',
# );

# TODO Add smart sentence segmenter
# which will do nothing if the text is already segmented.
# Perhaps add W2A::EN::Segment if_segmented=skip.
# This way we could use both
# treex Read::Sentences Scen::Analysis::EN
# treex Read::Text Scen::Analysis::EN

sub get_scenario_string {
    my ($self) = @_;

    my @blocks;

    if ($self->tokenizer ne 'none') {
        push @blocks,
            $self->tokenizer eq 'whitespace' ?
                'W2A::TokenizeOnWhitespace'
                : 'W2A::EN::Tokenize',
            'W2A::EN::NormalizeForms',
            'W2A::EN::FixTokenization',
            $self->gazetteer && defined $self->trg_lang ?
                'W2A::EN::GazeteerMatch trg_lang='.$self->trg_lang.' filter_id_prefixes="'.$self->gazetteer.'"'
                : (),
            ;
    }

    if ($self->tagger ne 'none') {
        push @blocks,
            $self->tagger eq 'Morce' ? 'W2A::EN::TagMorce' : (),
            $self->tagger eq 'MorphoDiTa' ? 'W2A::EN::TagMorphoDiTa' : (),
            'W2A::EN::FixTags',
            'W2A::EN::FixTagsImperatives',
            'W2A::EN::Lemmatize',
            $self->domain eq 'IT' ? ' W2A::EN::QtHackTags' : (),
            ;
    }

    if ($self->ner ne 'none') {
        push @blocks,
            $self->ner eq 'NameTag' ?  'A2N::EN::NameTag' : (),
            $self->ner eq 'Stanford' ? 'A2N::EN::StanfordNamedEntities model=ner-eng-ie.crf-3-all2008.ser.gz' : (),
            'A2N::EN::DistinguishPersonalNames',
            #'A2N::FixMissingLinks', # without this A2N::NestEntities throws errors
            #'A2N::NestEntities', # entities in n-trees should be nested, but adding this makes en-cs TectoMT BLEU worse
            ;
    }

    if ($self->parser ne 'none') {
        push @blocks,
            'W2A::MarkChunks',
            'W2A::EN::ParseMST model=conll_mcd_order2_0.01.model',
            'W2A::EN::SetIsMemberFromDeprel',
            'W2A::EN::RehangConllToPdtStyle',
            'W2A::EN::FixNominalGroups',
            'W2A::EN::FixIsMember',
            'W2A::EN::FixAtree',
            'W2A::EN::FixMultiwordPrepAndConj',
            'W2A::EN::FixDicendiVerbs',
            'W2A::EN::SetAfunAuxCPCoord',
            'W2A::EN::SetAfun',
            'W2A::FixQuotes',
            'A2A::ConvertTags input_driver=en::penn',
            'A2A::EN::EnhanceInterset',
            ;
    }

    if ($self->tecto ne 'none') {
        push @blocks,
            'A2T::EN::MarkEdgesToCollapse',
            'A2T::EN::MarkEdgesToCollapseNeg',
            'A2T::BuildTtree',
            'A2T::SetIsMember',
            'A2T::EN::MoveAuxFromCoordToMembers',
            $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
            'A2T::EN::FixTlemmas',
            'A2T::EN::SetCoapFunctors',
            'A2T::EN::FixApps',
            'A2T::EN::FixEitherOr',
            'A2T::EN::FixHowPlusAdjective',
            'A2T::FixIsMember',
            'A2T::EN::MarkClauseHeads',
            'A2T::EN::SetFunctors',
            'A2T::EN::MarkInfin',
            'A2T::EN::MarkRelClauseHeads',
            'A2T::EN::MarkRelClauseCoref',
            'A2T::EN::MarkDspRoot',
            'A2T::MarkParentheses',
            'A2T::SetNodetype',
            'A2T::EN::SetFormemeInterset',
            $self->functors eq 'MLProcess' ? 'A2T::EN::SetFunctors2 memory=2g' : (),
            $self->functors eq 'MLProcess' ? 'A2T::EN::SetMissingFunctors' : (), # mask unrecognized functors
            $self->functors eq 'MLProcess' ? 'A2T::SetNodetype' : (), # nodetype setting using functors -- caused problems in translation
            'A2T::EN::SetTense',
            'A2T::EN::SetGrammatemes',
            'A2T::SetGrammatemesFromAux',
            'A2T::EN::SetSentmod',
            'A2T::EN::RehangSharedAttr',
            'A2T::EN::SetVoice',
            'A2T::EN::FixImperatives',
            'A2T::EN::SetIsNameOfPerson',
            'A2T::EN::SetGenderOfPerson',
            'A2T::EN::AddCorAct',
            'T2T::SetClauseNumber',
            'A2T::EN::FixRelClauseNoRelPron',
            $self->functors eq 'VW' ? 'A2T::EN::SetFunctorsVW' : (),
            $self->functors eq 'VW' ? 'A2T::SetNodetype' : (), # fix nodetype changes induced by functors
            $self->valframes ? 'A2T::EN::SetValencyFrameRefVW' : (),
            $self->mark_it ? 'A2T::EN::MarkReferentialIt resolver_type=nada threshold=0.5 suffix=nada_0.5' : (), # you need Treex::External::NADA installed for this
            $self->coref eq 'BART' ? 'Coref::EN::ResolveBART2 is_czeng=1' : 'A2T::EN::FindTextCoref',
            ;
    }

    return join "\n", @blocks;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::EN - English analysis (tokenize, tag, NER, parse, tecto)

=head1 SYNOPSIS

 #== From command line ==
 treex -Len Read::Sentences from=my.txt Scen::Analysis::EN Write::Treex to=my.treex.gz

 treex --dump_scenario Scen::Analysis::EN

 #== From scenario ==
 # do tokenization, tagging, NER and parsing, but skip tecto-analysis
 Scen::Analysis::EN tecto=none

 # do tagging and NER, but skip parsing and tecto and assume flat a-trees on input
 Scen::Analysis::EN tokenizer=none parser=none tecto=none

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging (Morce / MorphoDiTa), lemmatization,
NER (NameTag / Stanford), dependency parsing (MST) and tectogrammatical analysis.

Note that Morce tagger cannot be instantiated twice -- therefore,
this scenario cannot be invoked more than once in one call to Treex.
If this is a problem for you, you either have to use separate calls to Treex,
writing out your data to disk and then reading them back between the calls,
or use MorphoDiTa instead of Morce.

=head1 PARAMETERS

=head2 MAIN PARAMETERS

=head3 tokenizer (default, whitespace, none)
C<none> assumes pretokenized flat a-trees on the input.
C<whitespace> tokenizes on whitespace only using C<W2A::TokenizeOnWhitespace>,
i.e. assumes no nodes but pretokenized sentence string.
C<default> uses C<W2A::EN::Tokenize>.

=head3 tagger (Morce, MorphoDiTa, none)

Morce = W2A::EN::TagMorce

MorphoDiTa = W2A::EN::TagMorphoDiTa

=head3 ner (NameTag, Stanford, none)

NameTag = A2N::EN::NameTag

Stanford = A2N::EN::StanfordNamedEntities model=ner-eng-ie.crf-3-all2008.ser.gz

=head3 parser (MST, none)

MST = W2A::EN::ParseMST model=conll_mcd_order2_0.01.model
Use "none" to end the scenario after tagging/ner.

=head3 tecto (default, none)

Use "none" to end the scenario after parsing.

=head2 OTHER PARAMETERS

=head3 domain (general, IT)

=head3 functors (simple, MLProcess, VW)

simple = A2T::EN::SetFunctors

MLProcess = A2T::EN::SetFunctors2 (functors trained from PEDT, extra 2GB RAM needed)

VW = A2T::EN::SetFunctorsVW (VowpalWabbit model trained on PEDT)

=head3 coref (simple, BART)

simple = A2T::EN::FindTextCoref (old rule-based CR for possessives looking for the anteceent within the same sentence)

BART = Coref::EN::ResolveBART2 (full-fledged CR, requires Java 1.7 and 5G mem, default timeout 120s for one document or CzEng block)

=head3 valframes (boolean)

Set valency frame references (IDs in the EngVallex dictionary) indicating the word sense
of all verbs (defaults to 0)?

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
