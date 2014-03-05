package Treex::Block::SemevalABSA::SubjectOfSubjectivePat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_ttree {
    my ( $self, $ttree ) = @_;

    my $amapper = $self->get_alayer_mapper( $ttree );

    my @patients = grep { $_->functor eq 'PAT' } $ttree->get_descendants;

    for my $pat (@patients) {
        my @polarities = 
            map { $self->get_polarity( $_ ) }
            grep { $self->is_subjective( $_ ) }
            map { $amapper->( $_ ) }
            $self->get_clause_descendants( $pat );

        if (@polarities) {
            my $total = $self->combine_polarities( @polarities );
            my $pred = $self->find_predicate( $pat );
            next if ! $pred;
            my @actors = grep { $_->functor eq 'ACT' } $self->get_clause_descendants( $pred );
            map { $self->mark_node( $amapper->( $_ ), "subj_of_pat_" . $total ) } @actors;
        }
    }

    return 1;
}

1;

# Pokud jsem podmet konstrukce, jejiz patiens je rozvity hodnoticim adjektivem, jsem aspekt.
#
#     Pr. The bagel ACT have an ourstanding RSTR taste PAT.
