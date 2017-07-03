package Treex::Scen::Analysis::PL;
use Moose;
use Treex::Core::Common;

has unknown_afun_to_atr => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has default_functor => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'W2A::UDPipe tokenize=1 model_alias="pl"',
    'HamleDT::UdepToPrague',
    q(Util::Eval anode='$.set_afun($.deprel)'),
    $self->unknown_afun_to_atr ? q(Util::Eval anode='if ($.afun =~ /^(Apposition)|(NR)|(Neg)$/) {$.set_afun("Atr")}') : (),
    
    # tecto analysis
    'A2T::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::PL::SetCoapFunctors',
#    q(Util::Eval tnode='print $.t_lemma."\n" if ($.is_coap_root);')
    'A2T::FixIsMember',
    'A2T::HideParentheses',
    'A2T::SetSentmod',
    'A2T::MoveAuxFromCoordToMembers',
#    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::MarkClauseHeads',
    'A2T::MarkRelClauseHeads',
    'A2T::MarkRelClauseCoref ',
    'A2T::SetNodetype',
    'A2T::SetFormeme',
    $self->default_functor ? (sprintf 'Util::Eval tnode=\'$.set_functor("%s")\'', $self->default_functor) : (),
    'A2T::SetGrammatemes',
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

Treex::Scen::Analysis::PL - Polish tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Leu Read::Sentences from=my.txt Scen::Analysis::PL Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::PL

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging and dependency parsing and tectogrammatical analysis.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
