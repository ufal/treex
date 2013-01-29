package Treex::Tool::ML::VowpalWabbit::Model;

use Moose;

use Treex::Core::Common;

use VowpalWabbit;
use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Compress::Index;

with 'Treex::Tool::ML::Classifier', 'Treex::Tool::Storage::Storable';

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

has '_last_instance' => (
    is => 'rw',
    isa => 'ArrayRef|HashRef',
);

has '_last_prediction' => (
    is => 'rw',
    isa => 'ArrayRef[Num]',
);

sub _vw_predict {
    my ($self, $example_str) = @_;
    
    my $vw = VowpalWabbit::create_vw();
    VowpalWabbit::add_buffered_regressor($vw, $self->model);
    VowpalWabbit::initialize_empty_vw($vw, "-t /dev/null --quiet");
    
    #my $vw = $self->_vw;
    my $example = VowpalWabbit::read_example($vw, $example_str);
    $vw->learn($vw, $example);
    my $results = VowpalWabbit::get_predictions($example);
    VowpalWabbit::finish_example($vw, $example);

    VowpalWabbit::finish($vw);

    return $results;
}

sub score {
    my ($self, $x, $y) = @_;

    my $pred;
    if (defined $self->_last_instance && ($x == $self->_last_instance)) {
        $pred = $self->_last_prediction;
    }
    else {
        my $x_str = Treex::Tool::ML::VowpalWabbit::Util::instance_to_vw_str( $x );
        $pred = $self->_vw_predict( $x_str );

        $self->_set_last_instance( $x );
        $self->_set_last_prediction( $pred );
    }
    my $y_idx = $self->index->get_index( $y );
    return $pred->[ $y_idx - 1 ];
}

sub log_feat_weights {
    my ($self, $x, $y) = @_;
    # TODO not implemented
    return ();
}

sub all_classes {
    my ($self) = @_;
    return $self->index->all_labels;
}

############# implementing Treex::Tool::Storage::Storable role #################

before 'save' => sub {
    my ($self, $filename) = @_;
    log_info "Storing VowpalWabbit model into $filename...";
};

before 'load' => sub {
    my ($self, $filename) = @_;
    log_info "Loading VowpalWabbit model from $filename...";
};

sub freeze {
    my ($self) = @_;

    my $frozen_index = $self->index->freeze;
    return [ $self->model, $frozen_index ];
}

sub thaw {
    my ($self, $buffer) = @_;

    my $index = Treex::Tool::Compress::Index->new();
    $index->thaw($buffer->[1]);

    $self->_set_index( $index );
    $self->index->build_inverted_index;

    $self->_set_model( $buffer->[0] );
}

1;
