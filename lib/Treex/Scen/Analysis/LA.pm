package Treex::Scen::Analysis::LA;
use Moose;
use Treex::Core::Common;

has harmonize_from_conll => (is=>'ro', isa=>'Bool', default=>0, documentation=>'Expect Index Thomisticus conll files on the input.');

#has shorten_ids =>
# TODO add blocks
# Optionally, backup original IDs to a wild attribute
#Util::Eval anode='$.wild->{origid}=$.id;'
#
# Make IDs shorter and without escape sequences (original ids were e.g a-004.4SN.DS13QU1.AR2CRA-2.8-4.11-6W1)
# Util::Eval anode='$.set_id($.generate_new_id)'


my $A2T_SCEN = <<'END';
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
A2T::LA::MarkRelClauseHeads
A2T::LA::MarkRelClauseCoref
#TODO A2T::LA::FixTlemmas
#TODO A2T::LA::FixNumerals
A2T::LA::SetGrammatemes
A2T::LA::AddPersPron
A2T::LA::TopicFocusArticulation
END

sub get_scenario_string {
    my ($self) = @_;

    my $scen = '';
    if ($self->harmonize_from_conll) {
        $scen .= 'HamleDT::LA::HarmonizeIT ';
    }

    $scen .= $A2T_SCEN;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::LA - Latin tectogrammatical analysis (from parsed a-trees)

=head1 SYNOPSIS

 # From command line
 treex -Lla Read::CoNLLX from=index_thomisticus.conll \
   Scen::Analysis::LA harmonize_from_conll=1 \
   Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::LA harmonize_from_conll=1

=head1 DESCRIPTION

This scenario starts with HamleDT::LA::HarmonizeIT and continues with A2T conversion,
so parsed Index-Thomisticus-style a-trees are expected on the input.

=head1 PARAMETERS

=head3 harmonize_from_conll
expect Index Thomisticus conll files on the input.
and add block C<HamleDT::LA::HarmonizeIT> to the beginning of the scenario.

=head1 AUTHORS

Christophe Onambele <christophe.onambele@unicatt.it>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
