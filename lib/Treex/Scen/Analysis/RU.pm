package Treex::Scen::Analysis::RU;
use Moose;
use Treex::Core::Common;

has tokenized => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

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
    $self->tokenized ? '' : 'W2A::RU::Tokenize',
    # first run tree tagger, because it seems to produce better lemmas
    'W2A::TagTreeTagger lemmatize=1',
    # copy the TreeTagger lemma to the wild
    q(Util::Eval anode='$.wild->{tt_lemma} = $.lemma'),
    # Run Russian UDPipe
    'W2A::UDPipe tokenize=0 model_alias=ru_prague',
    # copy UDPipe lemma to the wild and restore the TreeTagger lemma
    q(Util::Eval anode='$.wild->{udp_lemma} = $.lemma; $.set_lemma($.wild->{tt_lemma})'),
    q(Util::Eval anode='$.set_tag($.conll_pos)'),
    q(Util::Eval anode='$.set_afun($.deprel)'),
    q(Util::Eval anode='$.set_iset_conll_feat($.conll_feat)'),
    # rehang final punctuation
    q(Util::Eval anode='if ($.conll_pos =~ /^Z/ && !$.get_next_node) {$.set_parent($.get_root)}'),
    # set is_member
    q(Util::Eval anode='my $afun = $.afun; if ($afun =~ /_M$/) {$.set_is_member(1); $afun =~ s/_M$//; $.set_afun($afun)}'),
    $self->unknown_afun_to_atr ? q(Util::Eval anode='if ($.afun =~ /^(Apposition)|(NR)|(Neg)$/) {$.set_afun("Atr")}') : (),
    'W2A::RU::FixPronouns',
    # tecto analysis
    'A2T::MarkEdgesToCollapse',
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::RU::SetCoapFunctors',
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
    'A2T::AddPersPronSb',
    'A2T::MinimizeGrammatemes',
    'A2T::FixAtomicNodes',
    'A2T::MarkReflpronCoref',
    'T2T::SetClauseNumber',
    'A2T::SetDocOrds',
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
