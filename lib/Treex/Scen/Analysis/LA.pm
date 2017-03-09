package Treex::Scen::Analysis::LA;
use Moose;
use Treex::Core::Common;

## main parameters

has segmenter => (
    is => 'ro',
    handles => [qw(default none)],
    default => 'default',
);

has tokenizer => (
    is => 'ro',
    isa => enum( [qw(default none)] ),
    default => 'default',
);

has tagger => (
    is => 'ro',
    isa => enum( [qw(default none)] ),
    default => 'default',
    documentation => 'Which PoS tagger to use',
);

has parser => (
    is => 'ro',
    isa => enum( [qw(default none)] ),
    default => 'default',
    documentation => 'Which dependency parser to use',
);

has tecto => (
    is => 'ro',
    isa => enum( [qw(default none)] ),
    default => 'default',
    documentation => 'Which tectogrammatical analysis to use',
);

## parameters for detailed tuning of the scenario

#has functors => (
#    is => 'ro',
#    isa => enum( [qw(simple MLProcess VW)] ),
#    default => 'simple',
#    documentation => 'Which analyzer of functors to use',
#);

sub get_scenario_string {
    my ($self) = @_;
    my @blocks;

    if ($self->segmenter ne 'none'){
        push @blocks,
            'W2A::LA::Segment',
            ;
    }

    my $tokenize = $self->tokenizer eq 'none' ? 0 : 1;
    my $tag      = $self->tagger eq 'none' ? 0 : 1;
    my $parse    = $self->parser eq 'none' ? 0 : 1;

    push @blocks, "W2A::UDPipe model_alias=la_thomisticus tokenize=$tokenize tag=$tag parse=$parse"
        if $tokenize || $tag || $parse;
    if ($parse) {
        push @blocks, 'A2A::Deprel2Afun';
    }

    if ($self->tecto ne 'none') {
        push @blocks,
                'A2T::LA::MarkEdgesToCollapse',
                'A2T::BuildTtree',
                'A2T::RehangUnaryCoordConj',
                'A2T::SetIsMember',
                'A2T::LA::SetCoapFunctors',
                'A2T::FixIsMember',
                'A2T::MarkParentheses',
                'A2T::MoveAuxFromCoordToMembers',
                'A2T::LA::SetFunctors',
                'A2T::SetNodetype',
                'A2T::LA::MarkClauseHeads',
                'A2T::LA::MarkRelClauseHeads',
                'A2T::LA::MarkRelClauseCoref',
                #TODO 'A2T::LA::FixTlemmas',
                #TODO 'A2T::LA::FixNumerals',
                'A2T::LA::SetGrammatemes',
                'A2T::LA::AddPersPron',
                'A2T::LA::TopicFocusArticulation',
                ;
    }

    return join "\n", @blocks;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::LA - UDPipe model (a-layer) and tectogrammatical analysis

=head1 SYNOPSIS


=head1 DESCRIPTION

This scenario covers: segmentation, tokenization, tagging,
lemmatization, dependency parsing and tectogrammatical analysis.


=head1 AUTHORS

Christophe Onambele <christophe.onambele@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
