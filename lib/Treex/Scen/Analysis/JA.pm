package Treex::Scen::Analysis::JA;
use Moose;
use Treex::Core::Common;

#
# main parameters
#

has tokenizer => (
    is => 'ro',
    isa => enum( [qw(none MeCab whitespace)] ),
    default => 'MeCab',
);

has tagger => (
     is => 'ro',
     isa => enum( [qw(MeCab none)] ),
     default => 'MeCab',
);

has tagger_dict => (
    is => 'ro',
    isa => enum( [qw(UniDic ipadic)] ),
    default => 'UniDic'
);

has ner => (
     is => 'ro',
     isa => enum( [qw(none)] ),
     default => 'none',
     documentation => '',
);

has parser => (
     is => 'ro',
     isa => enum( [qw(Cabocha JDEPP none)] ),
     default => 'Cabocha',
     documentation => 'Which dependency parser to use',
);

has tecto => (
     is => 'ro',
     isa => enum( [qw(default none)] ),
     default => 'default',
     documentation => 'Which tectogrammatical analysis to use',
);


#
# parameters for detailed tuning of the analysis
#

has romanized_tags => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has functors => (
     is => 'ro',
     isa => enum( [qw(MLProcess simple VW)] ),
     default => 'MLProcess',
);

has valframes => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
);

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => '',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
);

# TODO gazetteers should work without any dependance on target language
has trg_lang => (
    is => 'ro',
    isa => 'Str',
);

#
# main method
#

sub get_scenario_string {
    my ($self) = @_;
    my @blocks = ();

    if ($self->tokenizer ne 'none'){
        push @blocks,
            $self->tokenizer eq 'whitespace' ? 'W2A::TokenizeOnWhitespace' : ();
            #$self->gazetteer && defined $self->trg_lang ?
            #    'W2A::GazeteerMatch trg_lang=' . $self->trg_lang . ' filter_id_prefixes="' . $self->gazetteer . '"' :
            #    (),
            #;
    }

    if ($self->tagger ne 'none'){
        push @blocks,
            $self->tagger eq 'MeCab' ? 'W2A::JA::TagMeCab dictionary_path_prefix=installed_tools/tagger/MeCab/lib/mecab/dic dictionary_type=' . $self->tagger_dict : (),
            $self->romanized_tags ? 'W2A::JA::RomanizeTags' : (),
            # TODO: tagger postprocessing?
            ;
    }

    if ($self->ner ne 'none'){
        push @blocks, ();
        # PLACEHOLDER
    }

    if ($self->parser ne 'none') {
        push @blocks,
            $self->parser eq 'Cabocha' ? 'W2A::JA::ParseCabocha' : (),
            $self->parser eq 'JDEPP' ? 'W2A::JA::ParseJDEPP' : (),
            # TODO: parser postprocessing?
            ;
    }

    if ($self->tecto ne 'none') {
        push @blocks,
            'A2T::MarkEdgesToCollapse',
            'A2T::JA::MarkEdgesToCollapseNeg',
            'A2T::BuildTtree',
            'A2T::SetIsMember',
            #'A2T::CS::SetCoapFunctors',
            'A2T::FixIsMember',
            'A2T::MarkParentheses',
            'A2T::MoveAuxFromCoordToMembers',
            #'A2T::CS::MarkClauseHeads',
            #'A2T::CS::MarkRelClauseHeads',
            #'A2T::CS::MarkRelClauseCoref',
            #A2T::DeleteChildlessPunctuation We want quotes as t-nodes
            $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
            #'A2T::CS::FixTlemmas',
            #'A2T::CS::FixNumerals',
            'A2T::SetNodetype',
            #'A2T::CS::SetFormeme use_version=2 fix_prep=0',
            #'A2T::CS::SetDiathesis',
            #$self->functors eq 'MLProcess' ? 'A2T::CS::SetFunctors memory=2g' : (),
            #$self->functors eq 'VW' ? 'A2T::CS::SetFunctorsVW' : (),
            #$self->functors ne 'VW' ? 'A2T::CS::SetMissingFunctors': (),
            'A2T::SetNodetype',
            'A2T::FixAtomicNodes',
            'A2T::JA::SetGrammatemes',
            'A2T::SetSentmod',
            #$self->valframes ? 'A2T::CS::SetValencyFrameRefVW' : (),
            #'A2T::CS::MarkReflexivePassiveGen',
            #'A2T::CS::FixNonthirdPersSubj',
            #'A2T::CS::AddPersPron',
            'T2T::SetClauseNumber',
            #'A2T::CS::MarkReflpronCoref',
            'A2T::SetDocOrds',
            #'Coref::CS::SetMultiGender',
            #'A2T::CS::MarkTextPronCoref',
            'Coref::RearrangeLinks retain_cataphora=1',
            'Coref::DisambiguateGrammatemes',
            ;
    }

    return join "\n", @blocks;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::JA - Japanese tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Lja Read::Sentences from=my.txt Scen::Analysis::JA Write::Treex to=my.treex.gz

 treex --dump_scenario Scen::Analysis::JA

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging+lemmatization (MeCab),
dependency parsing (Cabocha) and tectogrammatical analysis (limited - in developement).

The scenario is based on Treex::Scen::Analysis::CS block.

=head1 PARAMETERS

=item tagger

Which PoS tagger to use: 
C<tagger=MeCab> (default)
or C<tagger=none> (for pre-tagged text).

=item ner

TODO

=item parser

Which parser to use -- C<parser=Cabocha> (default), C<parser=JDEPP>
or C<parser=none> (if parsing is not required).

=item tecto

Which t-layer conversion to use -- C<tecto=default>
or C<tecto=none> (if tecto-analysis is not required).

=item domain

Domain of the input texts: C<domain=general> (default), or C<domain=IT>.

=item functors

Which analyzer of functors to use:
C<functors=MLProcess> (default), or C<functors=simple>, or C<functors=VW>.

=item gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo?
C<gazetteer=0> (default), or C<gazetteer=all>,
and other options -- see L<W2A::GazeteerMatch>.

=item trg_lang

Gazetteers are defined for language pairs. Both source and target languages must be specified.

=item valframes

Set valency frame references to valency dictionary?
C<valframes=0> (default), or C<valframes=1>.

=back

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
