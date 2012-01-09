package Treex::Tool::Coreference::DistrModelComponent::SentDist;

use Moose;

with 'Treex::Tool::Coreference::DistrModelComponent';

has 'sent_dist_count' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
    default     => 2, 
);

sub _select_features {
    my ($self, $anaph, $cand) = @_;
    my $cand_dist = $cand->{'c_sent_dist'};
    return ($cand_dist);
}

sub _base_distrib {
    my ($self, $cand_dist, $anaph_dist) = @_;

    return (1 / $self->sent_dist_count);
}

1;
