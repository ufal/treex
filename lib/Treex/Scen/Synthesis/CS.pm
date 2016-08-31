package Treex::Scen::Synthesis::CS;
use Moose;
use Treex::Core::Common;

has project_case => ( is => 'rw', isa => 'Bool', default => 0 );

has inflect_by_ending => ( is => 'rw', isa => 'Bool', default => 1 );

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'T2A::CS::CopyTtree',
    'T2A::CS::DistinguishHomonymousMlemmas',
    'T2A::CS::ReverseNumberNounDependency',
    'T2A::CS::InitMorphcat',
    'T2A::CS::FixPossessiveAdjs',
    'T2A::CS::MarkSubject',
    'T2A::CS::ImposePronZAgr',
    'T2A::CS::ImposeRelPronAgr',
    'T2A::CS::ImposeSubjpredAgr',
    'T2A::CS::ImposeAttrAgr',
    'T2A::CS::ImposeComplAgr',
    'T2A::CS::DropSubjPersProns',
    'T2A::CS::AddPrepos',
    'T2A::CS::AddSubconjs',
    'T2A::CS::AddReflexParticles',
    'T2A::CS::AddAuxVerbCompoundPassive',
    'T2A::CS::AddAuxVerbModal',
    'T2A::CS::AddAuxVerbCompoundFuture',
    'T2A::CS::AddAuxVerbConditional',
    'T2A::CS::AddAuxVerbCompoundPast',
    'T2A::CS::AddClausalExpletivePronouns',
    'T2A::CS::MoveQuotes',
    'T2A::CS::ResolveVerbs',
    'T2A::ProjectClauseNumber',
    'T2A::AddParentheses',
    'T2A::CS::AddSentFinalPunct',
    'T2A::CS::AddSubordClausePunct',
    'T2A::CS::AddCoordPunct',
    'T2A::CS::AddAppositionPunct',
    'T2A::CS::ChooseMlemmaForPersPron',
    'T2A::CS::GenerateWordforms inflect_by_ending=' . $self->inflect_by_ending,
    'T2A::CS::DeleteSuperfluousAuxCP',
    'T2A::CS::MoveCliticsToWackernagel',
    'T2A::CS::DeleteEmptyNouns',
    'T2A::CS::VocalizePrepos',
    'T2A::CS::CapitalizeSentStart',
    'T2A::CS::CapitalizeNamedEntitiesAfterTransfer',
    $self->project_case ? "A2A::ProjectCase" : (),
    'A2W::ConcatenateTokens',
    'A2W::CS::ApplySubstitutions',
    'A2W::CS::DetokenizeUsingRules',
    'A2W::CS::RemoveRepeatedTokens',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Synthesis::CS - Czech synthesis from t-trees

=head1 SYNOPSIS

 # From command line
 treex -Len Scen::Synthesis::CS Write::Sentences -- cs_ttrees.treex.gz

 treex --dump_scenario Scen::Synthesis::CS

=head1 DESCRIPTION

Synthesis from tectogrammatical trees to surface sentences.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
