package Treex::Scen::Analysis::PT;
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

has lxsuite_key => (
    is => 'ro',
    isa => 'Str',
    default => 'nlx.qtleap.13417612987549387402',
    documentation => 'Secret password to access Portuguese servers',
);

has lxsuite_host => (
    is => 'ro',
    isa => 'Str',
    default => '194.117.45.198',
);

has lxsuite_port => (
    is => 'ro',
    isa => 'Str',
    default => '10000',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    #'Util::SetGlobal lxsuite_host=' . $self->lxsuite_host . ' lxsuite_port=' . $self->lxsuite_port,
    #'Util::SetGlobal lxsuite_key=' . $self->lxsuite_key,
    'W2A::ResegmentSentences',
    'W2A::PT::LXSuite',
    'W2A::PT::FixTags',
    'W2A::NormalizeForms',
    'W2A::MarkChunks min_quotes=3',
    $self->gazetteer && defined $self->trg_lang ? 'W2A::PT::GazeteerMatch trg_lang='.$self->trg_lang.' filter_id_prefixes="'.$self->gazetteer.'"' : (),
    # a-layer
    #'W2A::PT::Parse lxsuite_mode=conll.pos:parser:conll.usd',
    'HamleDT::PT::HarmonizeCintilUSD',
    q(Util::Eval anode='$.set_afun($.deprel)'),
    'W2A::PT::FixAfuns',
    # t-layer
    'A2T::PT::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::PT::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::MarkParentheses',
    'A2T::MoveAuxFromCoordToMembers',
    'A2T::MarkClauseHeads',
    'A2T::MarkRelClauseHeads',
    'A2T::MarkRelClauseCoref',
    'A2T::DeleteChildlessPunctuation',
    # lexical transformation of lemmas to t-lemmas should be here
    'A2T::SetNodetype',
    'A2T::SetFormeme',
    'A2T::PT::FixFormeme',
    'A2T::PT::SetGrammatemes',
    'A2T::PT::SetGrammatemesFromAux',
    'A2T::AddPersPronSb',
    'A2T::MinimizeGrammatemes',
    'A2T::SetSentmod',
    'A2T::PT::FixImperatives',
    'A2T::PT::FixPersPron',
    'A2T::SetNodetype',
    'A2T::FixAtomicNodes',
    'A2T::MarkReflpronCoref',
    'T2T::FixPunctFormemes',
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::PT - Portuguese tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Lpt Read::Sentences from=my.txt Scen::Analysis::PT Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::PT

=head1 DESCRIPTION

This scenario needs to run "LX-Suite" tools on remote server.

TODO: describe the scenario

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
