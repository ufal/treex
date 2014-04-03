use Treex::Tool::Coreference::Features::Container;

use Moose;

with 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

sub _binary_features {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($set_features, $anaph, $cand, $candord);
        %feats = (%feats, %$fe_feats);
    }
    return \%feats;
}

sub _unary_features {
    my ($self, $node, $type) = @_;
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_unary_features($node, $type);
        %feats = (%feats, %$fe_feats);
    }
    return \%feats;
}


1;
