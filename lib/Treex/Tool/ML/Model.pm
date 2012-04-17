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
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::Model

=head1 DESCRIPTION

A role for models, most commonly trained by some of the ML methods.
It provides loading of the model from the Treex share.

=head1 PARAMETERS

=over

=item model_path

A path to the model, relative to the Treex shared directory.

=back

=head1 ATTRIBUTES

=over

=item _model

A protected attribute that should not be accessed from outside of 
this role or classes that consume this role. However, its isa type
ought to be adjusted to the type the consuming class actually works with.

=back

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item load_model

Loads a model and returns it as a single object. The isa type of 
the object representing the model (in attribute C<_model>) 
should be overloaded in a consuming class.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
