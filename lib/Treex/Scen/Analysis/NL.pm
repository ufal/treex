package Treex::Scen::Analysis::NL;
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
     default => 0,
     documentation => 'Use W2A::NL::GazeteerMatch A2T::ProjectGazeteerInfo, default=0',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'W2A::NL::Tokenize',
    #$self->gazetteer ? 'W2A::NL::GazeteerMatch' : ();
    'A2P::NL::ParseAlpino',
    'Util::Eval zone=\'$.remove_tree("a");\'',
    'P2A::NL::Alpino',
    'A2A::NL::EnhanceInterset',
    # a-layer to t-layer
    'A2T::NL::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::NL::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::MarkParentheses',
    'A2T::MoveAuxFromCoordToMembers',
    #$self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::MarkClauseHeads',
    'A2T::MarkRelClauseHeads',
    'A2T::MarkRelClauseCoref',
    #'A2T::DeleteChildlessPunctuation',  # we want quotes as t-nodes
    'A2T::NL::FixTlemmas',
    'A2T::NL::FixMultiwordSurnames',
    'A2T::SetNodetype',
    'A2T::NL::SetFormeme',
    'A2T::NL::SetGrammatemes',
    'A2T::NL::SetGrammatemesFromAux',
    'A2T::NL::SetSentmod',
    'A2T::NL::SetFunctors',
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

Treex::Scen::Analysis::NL - Dutch tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Lnl Read::Sentences from=my.txt Scen::Analysis::NL Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::NL

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging and dependency parsing (Alpino) and tectogrammatical analysis.

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 gazetteer

Use W2A::NL::GazeteerMatch A2T::ProjectGazeteerInfo
Note that for translation T2T::NL2XX::TrGazeteerItems Block is needed to translate identified items

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
