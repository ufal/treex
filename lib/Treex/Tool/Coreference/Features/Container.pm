package Treex::Tool::Coreference::Features::Container;

use Moose;
use Treex::Core::Common;

extends 'Treex::Tool::Coreference::CorefFeatures';

has 'feat_extractors' => (is => 'ro', isa => 'ArrayRef[Treex::Tool::Coreference::CorefFeatures]', required => 1);

override '_build_prefix_unary' => sub {
    return 0;
};

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_binary_features($set_features, $anaph, $cand, $candord);
        %feats = (%feats, %$fe_feats);
    }
    return \%feats;
};

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;
    
    my %feats = ();
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->_unary_features($node, $type);
        %feats = (%feats, %$fe_feats);
    }
    my $sub_feats = inner() || {};
    return { %feats, %$sub_feats };
};

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    foreach my $fe (@{$self->feat_extractors}) {
        my $fe_feats = $fe->init_doc_features($doc, $lang, $sel);
    }
}

1;
