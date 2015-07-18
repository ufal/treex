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
     isa => 'Bool',
     default => undef,
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo',
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->gazetteer){
        $self->{gazetteer} = $self->domain eq 'IT' ? 1 : 0;
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'W2A::Tokenize',
    #$self->gazetteer ? 'W2A::ES::GazeteerMatch' : ();
    'W2A::EU::TagAndParse',
    'HamleDT::EU::Harmonize',
    'W2A::EU::FixTagAndParse',
    'W2A::FixQuotes',
    'A2T::EU::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::EU::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::HideParentheses',
    'A2T::EU::SetSentmod',
    'A2T::MoveAuxFromCoordToMembers',
    #$self->gazetteer eq 'IT' ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::MarkClauseHeads',
    'A2T::MarkRelClauseHeads',
    'A2T::MarkRelClauseCoref ',
    'A2T::SetNodetype',
    'A2T::SetFormeme',
    'A2T::EU::SetGrammatemes',
    'A2T::SetGrammatemesFromAux',
    'A2T::AddPersPronSb',
    'A2T::MinimizeGrammatemes',
    'A2T::SetNodetype',
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

=head2 gazetteers

Use W2A::EU::GazeteerMatch A2T::ProjectGazeteerInfo
Note that for translation T2T::EU2XX::TrGazeteerItems Block is needed to translate identified items

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
