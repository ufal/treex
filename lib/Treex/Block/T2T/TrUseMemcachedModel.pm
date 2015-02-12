package Treex::Block::T2T::TrUseMemcachedModel;

use Moose::Role;
use Treex::Core::Log;

use Treex::Tool::Memcached::Memcached;
use Treex::Tool::TranslationModel::Memcached::Model;

requires 'model_dir';


# Load the model or create a memcached model over it
sub load_model {

    my ( $self, $model, $path, $memcached ) = @_;

    $path = $self->model_dir ?  $self->model_dir . '/' . $path : $path;

    if ($memcached) {
        $model = Treex::Tool::TranslationModel::Memcached::Model->new( { 'model' => $model, 'file' => $path } );
    }
    else {
        $model->load( Treex::Core::Resource::require_file_from_share($path) );
    }
    return $model;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrUseMemcachedModel - Helper role for loading Memcached models

=head1 DESCRIPTION

This role provides a simple helper method for loading either a memcached translation
model, if memcached should be used, or a plain model otherwise.


=head1 METHODS

=over

=item $model = load_model( $model_object, $model_data_path, $use_memcached )

Load a translation model into memory. If memcached is used, the model object is substituted
by a corresponding Memcached object, otherwise the load() method of the model object is called.  

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



