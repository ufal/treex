package Treex::Tool::ML::Model;

use Moose::Role;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

requires 'load_model';

has 'model_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',

    documentation => 'path to the trained model',
);

has '_model' => (
    is          => 'ro',
    required    => 1,
# isa type should be overloaded in a subclass
    isa         => 'Any',
    lazy        => 1,
    builder      => '_build_model',
);


# Attribute _model depends on the attribute model_path, whose value do not
# have to be accessible when building other attributes. Thus, _model is
# defined as lazy, i.e. it is built during its first access. However, we wish all
# models to be loaded while initializing a block. Following hack ensures it.
sub BUILD {
    my ($self) = @_;
    $self->_model;
}

sub _build_model {
    my ($self) = @_;

    my $model_file = require_file_from_share($self->model_path, ref($self));
    log_fatal 'File ' . $model_file . ' does not exist.' 
        if !-f $model_file;

    my $model = $self->load_model( $model_file );
    return $model;
}

1;
