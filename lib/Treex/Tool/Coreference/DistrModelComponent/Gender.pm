package Treex::Tool::Coreference::DistrModelComponent::Gender;

use Moose;

with 'Treex::Tool::Coreference::DistrModelComponent';

has 'gender_count' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
    default     => 7, 
);

sub _select_features {
    my ($self, $anaph, $cand) = @_;
    

    my $anaph_gen = $anaph->{'c_anaph_gen'};
    my $cand_gen = $cand->{'c_cand_gen'};
    
    return ($cand_gen, $anaph_gen);
}

sub _base_distrib {
    my ($self, $cand_gen, $anaph_gen) = @_;

    return (1 / $self->gender_count);
}

1;
