package Treex::Scen::Analysis::BG;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
A2T::BG::MarkEdgesToCollapse
A2T::BuildTtree
A2T::RehangUnaryCoordConj
A2T::SetIsMember
A2T::BG::SetCoapFunctors
A2T::FixIsMember
A2T::MarkParentheses
A2T::MoveAuxFromCoordToMembers
A2T::MarkClauseHeads
A2T::MarkRelClauseHeads
A2T::MarkRelClauseCoref
A2T::DeleteChildlessPunctuation
A2T::SetNodetype
A2T::SetFormeme
A2T::SetGrammatemes
A2T::BG::SetGrammatemesFromAux
A2T::AddPersPronSb
A2T::MinimizeGrammatemes
A2T::SetNodetype
A2T::FixAtomicNodes
A2T::MarkReflpronCoref
END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::BG - Bulgarian tectogrammatical analysis (from parsed a-trees)

=head1 SYNOPSIS

 # From command line
 treex -Lbg Read::CoNLLX from=btb.conll \
   A2A::BackupTree to_selector=origBTB \
   HamleDT::BG::Harmonize \
   Scen::Analysis::BG \
   Write::Treex to=my.treex.gz

 treex --dump_scenario Scen::Analysis::BG

=head1 DESCRIPTION

This scenario expects Prague-style a-trees on the input.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
