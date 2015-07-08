package Treex::Scen::Analysis::LA;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
# a-trees harmonization
HamleDT::LA::HarmonizeIT

# t-layer
A2T::LA::MarkEdgesToCollapse
A2T::BuildTtree
A2T::RehangUnaryCoordConj
A2T::SetIsMember
A2T::LA::SetCoapFunctors
A2T::FixIsMember
A2T::MarkParentheses
A2T::MoveAuxFromCoordToMembers
A2T::LA::SetFunctors
A2T::SetNodetype
A2T::LA::MarkClauseHeads
A2T::MarkRelClauseHeads
A2T::MarkRelClauseCoref
#TODO A2T::LA::FixTlemmas
#TODO A2T::LA::FixNumerals
A2T::LA::SetGrammatemes
#TODO A2T::LA::AddPersPron
END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::LA - Latin tectogrammatical analysis (from parsed a-trees)

=head1 SYNOPSIS

 # From command line
 treex -Lla Read::CoNLLX from=index_thomisticus.conll Scen::Analysis::LA Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::LA

=head1 DESCRIPTION

This scenario starts with HamleDT::LA::HarmonizeIT and continues with A2T conversion,
so parsed Index-Thomisticus-style a-trees are expected on the input.

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
