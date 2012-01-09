package Treex::Tool::Coreference::DistrModelComponent::ParentLemma;

use Moose;

with 'Treex::Tool::Coreference::DistrModelComponent';

has 'char_count' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
    default     => 57, 
);

sub _select_features {
    my ($self, $anaph, $cand) = @_;
    my $anaph_par_lemma = $anaph->{'c_anaph_epar_lemma'};
    my $cand_par_lemma = $cand->{'c_cand_epar_lemma'};
    
    #use Data::Dumper;
    #if (!defined $anaph_gen) {
    #    print STDERR Dumper($anaph);
    #    exit;
    #}
    #if (!defined $cand_par_lemma) {
    #    print STDERR Dumper($cand);
    #    exit;
    #}
    #print STDERR "ANAPH_GEN: $cand_gen\n";

    return ($cand_par_lemma, $anaph_par_lemma);
}

sub _base_distrib {
    my ($self, $cand_par_lemma, $anaph_par_lemma) = @_;

    my $len = length($anaph_par_lemma);
    my $prob = (0.5 ** $len) * ((1 / $self->char_count) ** $len);

    return $prob;
}

1;
