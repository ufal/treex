package Treex::Block::Segment::EstimateInterlinkCounts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::CS::CorefSegmentsFeatures;
#use AI::MaxEntropy::Model;
use Treex::Tool::ML::LinearRegression::Model;

has 'model_path' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
#    default => 'data/models/coreference/segments.maxent.gold',
    default => 'data/models/coreference/segments.lr.gold',
);

has '_model' => (
    is          => 'ro',
    isa         => 'Treex::Tool::ML::LinearRegression::Model',
#    isa         => 'AI::MaxEntropy::Model',
    required    => 1,
    lazy        => 1,
    builder     => '_build_model',
);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
# TODO this should be a role, not a concrete class
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefSegmentsFeatures',
    builder     => '_build_feature_extractor',
);

sub BUILD {
    my ($self) = @_;

    $self->_model;
}

sub _build_model {
    my ($self) = @_;
    
    my $model_file = require_file_from_share($self->model_path, ref($self));
    log_fatal 'File ' . $model_file . 
        ' with a model for coreference segmentation does not exist.' 
        if !-f $model_file;
    return Treex::Tool::ML::LinearRegression::Model->new({model_path => $model_file});
#    return AI::MaxEntropy::Model->new( $model_file );
}

sub _build_feature_extractor {
    my ($self) = @_;

    my $fe = Treex::Tool::Coreference::CS::CorefSegmentsFeatures->new();
    return $fe;
}

before 'process_document' => sub {
    my ($self, $doc) = @_;

    $self->_feature_extractor->init_doc_features( $doc, $self->language, $self->selector );
};

sub process_ttree {
    my ($self, $tree) = @_;

    my $instance = $self->_feature_extractor->extract_features( $tree );
    my $model = $self->_model;
    # get the score of the hypothesis that there is no break before the current sentence
    # my $score = $model->score($instance => 0);
    my $score = $model->predict( $instance );

    #print STDERR Dumper($instance);
    #print STDERR "SCORE: $score\n";

    # save the score for a further processing
    my $bundle = $tree->get_bundle;
    my $label = 'estim_interlinks/' . $self->language . '_' . $self->selector;
    $bundle->wild->{ $label } = $score;
}

1;
