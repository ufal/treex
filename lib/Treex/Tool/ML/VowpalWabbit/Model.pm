package Treex::Tool::ML::VowpalWabbit::Model;

use Moose;

use Treex::Core::Common;

use VowpalWabbit;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Compress::Index;

#with 'Treex::Tool::ML::Classifier', 'Treex::Tool::Storage::Storable';
with 'Treex::Tool::ML::Classifier', 
     'Treex::Tool::Storage::Storable' => {
        -alias => { load  => '_load', save => '_save' },
        -excludes => [ 'load', 'save' ],
     };


has 'model' => (
    is          => 'ro',
    isa => 'Str',
    writer => '_set_model',
);

has 'index' => (
    is => 'ro',
    isa => 'Treex::Tool::Compress::Index',
    writer => '_set_index',
);

has 'feat_map' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Str]]',
    writer => '_set_feat_map',
);

has '_last_instance' => (
    is => 'rw',
    isa => 'ArrayRef|HashRef',
);

has '_last_prediction' => (
    is => 'rw',
    isa => 'ArrayRef[Num]',
);

has '_last_feat_weights' => (
    is => 'rw',
    isa => 'HashRef[HashRef[Num]]',
);

has '_filename' => (
    is => 'rw',
    isa => 'Str',
);

has 'classes' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);


sub _vw_predict {
    my ($self, $example_str) = @_;
    
    my $vw = VowpalWabbit::create_vw();
    #VowpalWabbit::add_buffered_regressor($vw, $self->model);
    VowpalWabbit::initialize_empty_vw($vw, sprintf("-t -i %s --quiet", $self->_filename));
    
    #my $vw = $self->_vw;
    my $example = VowpalWabbit::read_example($vw, $example_str);
    $vw->learn($vw, $example);
    my $feats_idx = $vw->get_feats_idx($vw, $example);
    my $weights = $vw->get_weights($vw, $example);
    #my $feat_weights = $self->_create_feat_weights($feats_idx, $weights);
    my $results = VowpalWabbit::get_predictions($example);
    VowpalWabbit::finish_example($vw, $example);

    VowpalWabbit::finish($vw);

    my $feat_weights;
    return ($results, $feat_weights);
}

sub score {
    my ($self, $x, $y) = @_;

    my $pred;
    if (defined $self->_last_instance && ($x == $self->_last_instance)) {
        $pred = $self->_last_prediction;
    }
    else {
        my $x_str = Treex::Tool::ML::VowpalWabbit::Util::instance_to_vw_str( $x );
        my $feat_weigths;
        ($pred, $feat_weigths) = $self->_vw_predict( $x_str );

        $self->_set_last_instance( $x );
        $self->_set_last_prediction( $pred );
        #$self->_set_last_feat_weights( $feat_weigths );
    }
    #my $y_idx = $self->index->get_index( $y );
    #return $pred->[ $y_idx - 1 ];
    return $pred->[ $y - 1 ];
}

sub log_feat_weights {
    my ($self, $x, $y) = @_;
    
    if (!defined $self->_last_instance || ($x != $self->_last_instance)) {
        log_fatal "The 'score' method must be called first.";
    }
    my $feat_weigths = $self->_last_feat_weights;
    my $y_idx = $self->index->get_index( $y );
    return $feat_weigths->{$y_idx};
}

sub all_classes {
    my ($self) = @_;
    #return $self->index->all_labels;
    return @{$self->classes};
}

sub _create_feat_weights {
    my ($self, $feats_idx, $weights) = @_;
    
    #my $k = $self->index->last_idx;
    my $k = $self->classes->[-1];
    my $classed_feats_idx = Treex::Tool::ML::VowpalWabbit::Util::split_to_classes($feats_idx, $k);
    my $classed_weights = Treex::Tool::ML::VowpalWabbit::Util::split_to_classes($weights, $k);

    my $feat_weights = {};
    foreach my $class_idx (keys %$classed_feats_idx) {
        my $idx2name = $self->feat_map->{$class_idx};
        my $idx4class = $classed_feats_idx->{$class_idx};
        my $weight4class = $classed_weights->{$class_idx};

        my @name4class = map {$idx2name->{$_}} @$idx4class;
        my %name2weight;
        @name2weight{@name4class} = @$weight4class;
        $feat_weights->{$class_idx} = \%name2weight;
    }
    return $feat_weights;
}

############# implementing Treex::Tool::Storage::Storable role #################

#before 'save' => sub {
#    my ($self, $filename) = @_;
#    log_info "Storing VowpalWabbit model into $filename...";
#};

#before 'load' => sub {
#    my ($self, $filename) = @_;
#    log_info "Loading VowpalWabbit model from $filename...";
#};

sub load {
    my ($self, $filename) = @_;
    $filename = $self->_locate_model_file($filename);
    log_info "Loading vw model from $filename...";
    $self->_set_filename($filename);
}

sub freeze {
    my ($self) = @_;

    my $frozen_index = $self->index->freeze;
    return [ $self->model, $frozen_index, $self->feat_map ];
}

sub thaw {
    my ($self, $buffer) = @_;

    my $index = Treex::Tool::Compress::Index->new();
    $index->thaw($buffer->[1]);

    $self->_set_index( $index );
    $self->index->build_inverted_index;

    $self->_set_model( $buffer->[0] );

    $self->_set_feat_map( $buffer->[2] );
}

1;
