package Treex::Block::SemevalABSA::VerbActants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

sub process_atree {
    my ( $self, $atree ) = @_;

    my @preds = grep { $_->tag =~ m/^VB/ && $self->is_subjective( $_ ) } $atree->get_descendants;

    for my $pred (@preds) {
        my $polarity = $self->get_polarity( $pred );
        my $negated = grep { $_->lemma eq 'not' } $pred->get_children;
        $polarity = $self->switch_polarity( $polarity ) if $negated;
        my @subjects = grep { $_->afun =~ m/^Sb/ } $self->get_clause_descendants( $pred );
        my @objects = grep { $_->afun =~ m/^Obj/ } $self->get_clause_descendants( $pred );
        if (@objects) {
            map { $self->mark_node( $_, "verb_actant_pat$polarity" ) } @objects;
        } elsif (@subjects) {
            map { $self->mark_node( $_, "verb_actant_act$polarity" ) } @subjects;
        }
    }

    return 1;
}

1;

#     Pokud jsem hodnotici sloveso ze slovniku a mam jeden aktant, je to aspekt.
#
#         Pr. Their wine sucks.
#
#   Pokud jsem hodnotici sloveso ze slovniku a jsem tranzitivni, je aspekt muj pacient.
#
#         Pr. I liked the beer selection PAT.
