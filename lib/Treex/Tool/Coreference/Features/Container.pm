package Treex::Tool::Coreference::Features::Container;

use Moose;

extends 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($set_features, $anaph, $cand, $candord);
        %feats = (%feats, %$fe_feats);
    }
    return \%feats;
};

override '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_unary_features($node, $type);
        %feats = (%feats, %$fe_feats);
    }
    return \%feats;
};

override 'init_doc_features' => sub {
    my ($self, $doc, $lang, $sel) = @_;
    
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->init_doc_features($doc, $lang, $sel);
    }
};

1;
