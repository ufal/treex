package Treex::Scen::Synthesis::BG;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
T2A::CopyTtree
T2A::MarkSubject
T2A::InitMorphcat
T2A::AddPrepos
T2A::AddSubconjs
T2A::AddCoordPunct
T2A::ImposeSubjpredAgr
T2A::ImposeAttrAgr
T2A::DropPersPronSb
T2A::BG::AddAuxVerbs
T2A::BG::AddAuxVerbModalTense

T2A::ProjectClauseNumber
T2A::AddParentheses
T2A::AddSentFinalPunct

T2A::BG::MoveDefiniteness

Util::Eval anode='$.set_tag(join " ", $.get_iset_values())'

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Synthesis::BG - Bulgarian synthesis from t-trees

=head1 SYNOPSIS

 # From command line
 treex -Lbg Scen::Synthesis::BG Write::Sentences -- bg_ttrees.treex.gz

 treex --dump_scenario Scen::Synthesis::BG

=head1 DESCRIPTION

Synthesis from tectogrammatical trees to lemmatized a-trees with iset features.
TODO: wordform generation

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
