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

#    if (($cand_gen eq $anaph_gen ) && 
#        (($cand_gen eq 'anim') || ($cand_gen eq 'inan') ||
#         ($cand_gen eq 'neut') || ($cand_gen eq 'fem'))) {
#        return (0.5 / 4);
#    }
#    else {
#        return (0.5 / ($self->gender_count ** 2 - 4));
#    }

    return (1 / $self->gender_count);
}

1;
