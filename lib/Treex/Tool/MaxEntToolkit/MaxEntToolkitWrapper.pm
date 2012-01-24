package Treex::Tool::MaxEntToolkit::MaxEntToolkitWrapper;

use Moose;
use Treex::Core::Common;
use File::Temp;
use File::Slurp;
use autodie;

# path to maxent binary
has 'maxent_binary' => (
    is      => 'rw',
    isa     => 'Str',
    default => '${TMT_ROOT%/}/share/external_tools/MaxEntToolkit/maxent_x86_64',
);

# path to save model (when training) or read model from (when predicting)
has 'model' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

# temporary directory
has '_temp_dir' => ( is => 'ro', builder => '_create_temp_dir' );

# list of tempfiles
has '_tempfiles' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

### MaxEnt Toolkit API ###

# train maxent model with given set of instances
sub train {
    my ( $self, $instances_ref ) = @_;

    # write input to file
    my $input_file = $self->_create_input_file();
    write_file($input_file, {binmode => ':utf8'}, join("\n", @$instances_ref));

    # run maxent toolkit
    my $command = $self->maxent_binary . " " . $input_file . " -b -m " . $self->model . " -i 30";
    log_info("Running maxent toolkit with command:\n$command");
    my $exit_status = system($command);
    log_fatal("Maxent training exited unsuccessfully with return value: $exit_status.") unless $exit_status == 0;
}

# predict given instances
sub predict {
    my ( $self, @instances ) = @_;

    # write input to file
    my $input_file = $self->_create_input_file();
    write_file($input_file, {binmode => ':utf8'}, join("\n", map { "dummy_label ".$_ } @instances));

    # create output file
    my $output_file = $self->_create_output_file();

    # run maxent toolkit
    my $command = $self->maxent_binary . " -p ". $input_file . " -m " . $self->model . " -o " . $output_file;
    log_info("Running maxent toolkit with command:\n$command");
    my $exit_status = system($command);
    log_fatal("Maxent prediction exited unsuccessfully with return value: $exit_status.") unless $exit_status == 0;
    my @output_strings = split "\n", read_file($output_file);

    return @output_strings;
}

### File management ###

# create a new temporary directory
sub _create_temp_dir {
    my ($self) = @_;
    return File::Temp->newdir( CLEANUP => 1 );
}

# create a temporary file in the temporary directory, add it to the list of tempfiles
sub _create_temp_file {
    my ( $self, $name ) = @_;

    my $tempfile = File::Temp->new(
        TEMPLATE => 'maxent-' . $name . '-XXXX',
        UNLINK   => 1,
        DIR      => $self->_temp_dir->dirname
    );
    push @{ $self->_tempfiles }, $tempfile;
    return $tempfile;
}

# create input temporary file
sub _create_input_file {
    my ($self) = @_;
    return $self->_create_temp_file('input');
}

# create output temporary file
sub _create_output_file {
    my ($self) = @_;
    return $self->_create_temp_file('output');
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::MaxEntToolkit::MaxEntToolkitWrapper

=head1 SYNOPSIS

    # create maxent toolkit wrapper
    my $maxent = Treex::Tool::MaxEntToolkit::MaxEntToolkitWrapper->new({'model' => 'test_model'});

    # create some training instances
    my @instances = [ 'Outdoor Sunny Happy',
                      'Outdoor Sunny Happy Dry',
                      'Outdoor Sunny Happy Humid', 
                      'Indoor Rainy Happy Humid', 
                      'Indoor Rainy Happy Dry', 
                      'Indoor Rainy Sad Dry',
                    ];

    # train
    $maxent->train(@instances);

    # test
    my $instance = 'Sunny Happy Dry';
    my $predicted_output = $maxent->predict($instance);

=head1 DESCRIPTION

    A simple wrapper for the L<Maximum Entropy Toolkit|http://homepages.inf.ed.ac.uk/lzhang10/maxent_toolkit.html>.

=head1 PARAMETERS

=over

=item maxent_binary

    Path to maxent toolkit binary.

=item model

    Path to save model (when training) or read model from (when predicting). Required.

=back

=head1 METHODS 

=over

=item $self->train( @instances )

    Train the model and save it. Input format is an array reference with one
    instance per item. Each item is in format

    <instance> .=. <label> <feature> <feature> ...
    <feature> .=. string
    <label> .=. string

=item $self->predict( $instance )

    Predict classification of given instance. Input format is a string of features:

    <instance> .=. <feature> <feature> <feature> ...
    <feature> .=. string

=back

=head1 TODO
    
=over

=item Attribute 'iterations' to set number of training iterations.

=item Detailed prediction to output full probability distribution of possible outputs.

=back

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
