package Treex::Block::SemevalABSA::SubjectOfSubjectivePat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;

    my @objects = grep { $_->afun =~ m/^Obj/ } $atree->get_descendants;

    for my $obj (@objects) {
        my @polarities = 
            map { $self->get_polarity( $_ ) }
            grep { $self->is_subjective( $_ ) }
            $self->get_clause_descendants( $obj );

        if (@polarities) {
            my $total = $self->combine_polarities( @polarities );
            my $pred = $self->find_predicate( $obj );
            next if ! $pred;
            my $negated = grep { $_->lemma eq 'not' } $pred->get_children;
            $total = $self->switch_polarity( $total ) if $negated;
            my @subjects = grep { $_->afun =~ m/^Sb/ } $self->get_clause_descendants( $pred );
            map { $self->mark_node( $_, "subj_of_pat_" . $total ) } @subjects;
        }
    }

    return 1;
}

1;

# Pokud jsem podmet konstrukce, jejiz patiens je rozvity hodnoticim adjektivem, jsem aspekt.
#
#     Pr. The bagel ACT have an ourstanding RSTR taste PAT.
