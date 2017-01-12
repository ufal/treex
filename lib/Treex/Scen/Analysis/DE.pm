package Treex::Scen::Analysis::DE;
use Moose;
use Treex::Core::Common;

## main parameters

has tokenizer => (
    is => 'ro',
    isa => enum( [qw(default whitespace none)] ),
    default => 'none',
);

has tagger => (
     is => 'ro',
     isa => enum( [qw(Morce MorphoDiTa none)] ),
     default => 'none',
     documentation => 'Which PoS tagger to use',
);

has ner => (
     is => 'ro',
     isa => enum( [qw(NameTag Stanford none)] ),
     default => 'NameTag',
     documentation => 'Which Named Entity Recognizer to use',
);

has parser => (
     is => 'ro',
     isa => enum( [qw(MST none)] ),
     default => 'none',
     documentation => 'Which dependency parser to use',
);

has tecto => (
     is => 'ro',
     isa => enum( [qw(default none)] ),
     default => 'default',
     documentation => 'Which tectogrammatical analysis to use',
);

## parameters for detailed tuning of the scenario

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
    
    my @blocks;
    
    if ($self->tokenizer ne 'none') {
        # we use external run of MATE tools for tokenization, tagging and parsing.
        # The resulting CoNLL2009 file is then loaded and further processed
    }

    if ($self->tagger ne 'none') {
        # we use external run of MATE tools for tokenization, tagging and parsing.
        # The resulting CoNLL2009 file is then loaded and further processed
    }

    if ($self->ner ne 'none') {
        push @blocks,
            $self->ner eq 'NameTag' ?  'A2N::DE::NameTag' : (),
            ;
    }

    if ($self->parser ne 'none') {
        # we use external run of MATE tools for tokenization, tagging and parsing.
        # The resulting CoNLL2009 file is then loaded and further processed
    }
    
    if ($self->tecto ne 'none') {
        push @blocks,
            'A2T::MarkEdgesToCollapse',
            'A2T::BuildTtree',
            'A2T::RehangUnaryCoordConj',
            'A2T::SetIsMember',
            'A2T::DE::SetCoapFunctors',
#    q(Util::Eval tnode='print $.t_lemma."\n" if ($.is_coap_root);')
            'A2T::FixIsMember',
            'A2T::HideParentheses',
            'A2T::SetSentmod',
            'A2T::MoveAuxFromCoordToMembers',
#    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
            'A2T::MarkClauseHeads',
            'A2T::MarkRelClauseHeads',
            #'A2T::MarkRelClauseCoref ',
            'A2T::SetNodetype',
            'A2T::SetFormeme',
            $self->default_functor ? (sprintf 'Util::Eval tnode=\'$.set_functor("%s")\'', $self->default_functor) : (),
            'A2T::SetGrammatemes',
            'A2T::SetGrammatemesFromAux',
            'A2T::AddPersPronSb',
            'A2T::MinimizeGrammatemes',
            'A2T::FixAtomicNodes',
            #'A2T::MarkReflpronCoref',
            'T2T::SetClauseNumber',
            'A2T::SetDocOrds',
            ;
    }

    return join "\n", @blocks;
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
