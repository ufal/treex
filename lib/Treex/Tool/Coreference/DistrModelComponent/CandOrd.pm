package Treex::Tool::Coreference::DistrModelComponent::CandOrd;

use Moose;

with 'Treex::Tool::Coreference::DistrModelComponent';

has 'last_one_prob' => (
    is          => 'ro',
    isa         => 'Num',
    required    => 1,
    default     => 0.5, 
);

sub _select_features {
    my ($self, $anaph, $cand) = @_;
    my $cand_ord = $cand->{'c_cand_ord'};
    return ($cand_ord);
}

sub _base_distrib {
    my ($self, $cand_ord) = @_;

    return ($self->last_one_prob ** $cand_ord) * (1 - $self->last_one_prob);
}

1;
