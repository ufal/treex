package Treex::Tool::Coreference::Features::Morphological;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Coreference::CorefFeatures';

sub binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;
    
    my $coref_features = {};
    
    $coref_features->{c_join_apos}  
        = $self->_join_feats($set_features->{c_cand_apos}, $set_features->{c_anaph_apos});
    $coref_features->{c_join_anum}  
        = $self->_join_feats($set_features->{c_cand_anum}, $set_features->{c_anaph_anum});

    return $coref_features;
}

sub unary_features {
    my ($self, $node, $type) = @_;
    
    my $coref_features = {};
    return $coref_features;
}

1;
