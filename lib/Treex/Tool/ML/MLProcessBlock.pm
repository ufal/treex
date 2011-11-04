package Treex::Tool::ML::MLProcessBlock;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ML::MLProcess;

extends 'Treex::Core::Block';

# cleanup temporary files (default = 1)
has 'cleanup_temp' => ( is => 'ro', isa => 'Bool', default => 1 );

# Amount of memory needed for ML-Process Java VM
has 'memory' => ( is => 'ro', isa => 'Str', default => '1g' );

# Override the default treex error level for ML-Process (0 = nothing, 4 = debug)
has 'verbosity' => ( is => 'ro', isa => 'Maybe[Int]' );

# files related to the trained model (will be required from the shared directory)
has 'model_dir' => ( is => 'ro', isa => 'Str', writer => '_set_model_dir', required => 1 );
has 'plan_template' => ( is => 'ro', isa => 'Str', required => 1 );

# required files from the shared directory
has 'model_files' => ( is => 'ro', isa => 'ArrayRef', required => 1 );

# hash with plan template variables => file names, e.g. 'MODEL' => 'model.dat' ...
has 'plan_vars' => ( is => 'ro', isa => 'HashRef', required => 1 );

# name of the class attribute in the output data
has 'class_name' => ( is => 'ro', isa => 'Str', required => 1 );

# results loaded from the classfication of ML process, works as a FIFO (is first filled with the whole document, then subsequently emptied)
has '_results' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

# require files from the shared directory and save their actual path for the shared directory files
# TODO - this should be needed for ALL blocks, if the paths may end up different !!!
sub BUILD {

    my ($self) = @_;

    my @files = map { $self->model_dir . $_ } ( @{ $self->model_files } );

    my $name         = 'the block ' . $self->get_block_name();
    my $up_model_dir = 1;

    foreach my $file (@files) {
        my $target = Treex::Core::Resource::require_file_from_share( $file, $name );

        if ($up_model_dir) {
            $file   =~ s/([\/\\\[\]])/\\$1/g;
            $target =~ s/(.*)$file$/$1/;
            $self->_set_model_dir( $target . $self->model_dir );
            $up_model_dir = 0;
        }
    }
    return;
}

override 'process_document' => sub {

    my ( $self, $document ) = @_;

    my $params = {
        plan_template => $self->model_dir . $self->plan_template,
        cleanup_temp  => $self->cleanup_temp,
        memory        => $self->memory,
    };
    $params->{verbosity} = $self->verbosity if ( defined( $self->verbosity ) );
    my $mlprocess = Treex::Tool::ML::MLProcess->new($params);

    my $temp_input = $mlprocess->input_data_file;

    $self->_write_input_data( $document, $temp_input );

    # run ML-Process with the specified plan file
    $mlprocess->run(
        {
            map { $_ => $self->model_dir . $self->plan_vars->{$_} } keys %{ $self->plan_vars }
        }
    );

    # parse the output file and store the results
    $self->_set_results( $mlprocess->load_results( $self->class_name ) );

    # process all t-trees and fill them with the results
    super;

    # test if all results have been used
    if ( @{ $self->_results } != 0 ) {
        log_fatal("Too many results on the ML-Process output.");
    }
    return;
};

# self fills a t-tree with results, which must be preloaded in $self->_results
sub process_ttree {

    my ( $self, $root ) = @_;
    my @nodes = $self->_filter( $root->get_descendants( { ordered => 1 } ) );

    if ( scalar(@nodes) > scalar( @{ $self->_results } ) ) {
        log_fatal("Not enough results on the ML-Process output.");
    }
    foreach my $node (@nodes) {
        $self->_set_class_value( $node, shift @{ $self->_results } );
    }
    return;
}

# Write the input data for ML-Process based on the current file
sub _write_input_data {
    my ( $self, $document, $file_handle ) = @_;
    log_fatal( 'The class ' . ref($self) . ' must override the _write_input_data method.' );
}

# Set the ML-Process results back to the current file
sub _set_class_value {
    my ( $self, $node, $value ) = @_;
    log_fatal( 'The class ' . ref($self) . ' must override the _set_class_value method.' );
}

# No filtering done by default, but may be overridden by the derived classes
sub _filter {
    my ( $self, @nodes ) = @_;
    return @nodes;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::MLProcessBlock

=head1 DESCRIPTION

A base class for all blocks that just use the ML-Process library for the classification of one file and then distribute
the results to all nodes in that file.

All such classes must override the C<_write_input_data> and C<_set_class_value> methods and provide values for the
C<model_dir>, C<plan_template>, C<model_files> and C<class_name> parameters.


=head1 PARAMETERS

=over

=item model_dir

The directory where the pre-trained model for the ML-Process library is located (assumed to be in the shared directory).

=item plan_template

The ML-Process scenario file template (which is filled with file name values on each run).

=item model_files

A list of required files from the model directory. 

=item plan_vars

All pre-set values of variables in the scenario template file, i.e. a hash in the following format:
        
        { 'MODEL' => 'model.dat', ... }

=item class_name

The name of the attribute which ML-Process will classify and which is to be loaded into the individual nodes
(via the C<_set_class_value> method).

=item cleanup_temp

Should the ML-Process temporary files be deleted at the end of the processing (default: 1)?  

=item memory

Amount of memory to be used for ML-Process Java VM (default: 1g). Same settings as for C<java -Xmx> apply here.

=item verbosity

Verbosity setting for the ML-Process tool. Allowed values: 0 = nothing, 1 = warning, 2 = important,
3 = info, 4 = debug. If unset, a default is inferred from the current Treex error level. 

=back

=head1 METHODS

To be overridden:

=over

=item $self->_write_input_data( $document, $file_handle )

Write the input data for ML-Process based on the current file.

=item $self->_set_class_value( $node, $value )

Set the ML-Process results back to the current file (called for each node and the corresponding value retrieved
from the classification).

=tem $self->_filter( @nodes )

Filter a set of nodes and return only those that should have the class value assigned. If this method is not 
overridden, no filtering is done.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
