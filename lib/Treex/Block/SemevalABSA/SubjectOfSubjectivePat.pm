package Treex::Block::SemevalABSA::SubjectOfSubjectivePat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_ttree {
    my ( $self, $ttree ) = @_;
    my @patients = grep { $_->functor eq 'PAT' } $ttree->get_descendants;
    for my $pat (@patients) {
        my @polarities = 
            map { get_polarity( $_ ) }
            grep { is_subjective( $_ ) } get_clause_descendants( $pat );

        if (@polarities) {
            my $total = combine_polarities( @polarities );
            my $pred = find_predicate( $pat );
            next if ! $pred;
            my @actors = grep { $_->functor eq 'ACT' } get_clause_descendants( $parent );
            map { mark_node( $_, "subj_of_pat_" . $total ) } @actors;
        }
    }

    return 1;
}

1;

# Pokud jsem podmet konstrukce, jejiz patiens je rozvity hodnoticim adjektivem, jsem aspekt.
#
#     Pr. The bagel ACT have an ourstanding RSTR taste PAT.
