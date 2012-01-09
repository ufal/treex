package Treex::Tool::Coreference::DistrModelComponent::Number;

use Moose;

with 'Treex::Tool::Coreference::DistrModelComponent';

has 'number_count' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
    default     => 5, 
);

sub _select_features {
    my ($self, $anaph, $cand) = @_;
    my $anaph_num = $anaph->{'c_anaph_num'};
    my $cand_num = $cand->{'c_cand_num'};
    return ($cand_num, $anaph_num);
}

sub _base_distrib {
    my ($self, $cand_num, $anaph_num) = @_;

    return (1 / $self->number_count);
}

1;
