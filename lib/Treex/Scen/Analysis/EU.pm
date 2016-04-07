package Treex::Scen::Analysis::EU;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
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
    'W2A::Tokenize',
    $self->gazetteer && defined $self->trg_lang ? 'W2A::GazeteerMatch trg_lang='.$self->trg_lang.' filter_id_prefixes="'.$self->gazetteer.'"' : (),
    'W2A::EU::TagAndParse',
    'HamleDT::EU::Harmonize iset_driver=eu::eustagger',
    q(Util::Eval anode='$.set_afun($.deprel)'),
    'W2A::EU::FixTagAndParse',
    'W2A::EU::FixMultiwordPrepAndConj',
    'W2A::EU::FixModalVerbs',
    'A2T::EU::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::EU::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::HideParentheses',
    'A2T::EU::SetSentmod',
    'A2T::MoveAuxFromCoordToMembers',
    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::MarkClauseHeads',
    'A2T::MarkRelClauseHeads',
    'A2T::MarkRelClauseCoref ',
    'A2T::SetNodetype',
    'A2T::EU::SetFormeme',
    'A2T::EU::SetGrammatemes',
    'A2T::SetGrammatemesFromAux',
    'A2T::AddPersPronSb formeme_for_dropped_subj="n:[erg]+X"',
    'A2T::MinimizeGrammatemes',
    'A2T::FixAtomicNodes',
    'A2T::MarkReflpronCoref',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::EU - Basque tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Leu Read::Sentences from=my.txt Scen::Analysis::EU Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::EU

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging and dependency parsing (ixa-pipes-eu) and tectogrammatical analysis.

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
