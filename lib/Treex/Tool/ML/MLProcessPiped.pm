package Treex::Tool::ML::MLProcessPiped;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use File::Java;
use Treex::Tool::IO::Arff;
use autodie;
use ProcessUtils;

# The base directory for the ML-Process tool
Readonly my $ML_PROCESS_BASEDIR => 'installed_tools/ml-process/';

# All files the ML-Process tool needs for its work (except the executable JAR)
Readonly my $ML_PROCESS_LIBRARIES => [
    'lib/google-collect-1.0.jar',
    'lib/java-getopt-1.0.13.jar',
    'lib/liblinear-1.51.jar',
    'lib/libsvm-2.91.jar',
    'lib/lpsolve55j.jar',
    'lib/weka-3.7.1.jar',
    'dll_32/liblpsolve55.so',
    'dll_32/liblpsolve55j.so',
    'dll_64/liblpsolve55.so',
    'dll_64/liblpsolve55.so',
];

# ML-Process executable
has 'ml_process_jar' => (
    is      => 'ro',
    isa     => 'Str',
    default => $ML_PROCESS_BASEDIR . 'ml-process.jar',
    writer  => '_set_ml_process_jar'
);

# Verbosity
has 'verbosity' => ( is => 'ro', isa => enum( [ 0, 1, 2, 3, 4 ] ), lazy_build => 1 );

# Amount of memory needed for Java VM
has 'memory' => ( is => 'ro', isa => 'Str', default => '1g' );

# Path to the packed model data file
has 'model' => ( is => 'ro', isa => 'Str', required => 1, writer => '_set_model' );

# Caching settings (should be set to the sentence-id attribute name, or some reasonable numeric value)
has 'caching' => ( is => 'ro', isa => 'Str', default => '1' );

# ML-Process slave application controls (bipipe handles, application PID)
has 'read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has 'write_handle' => ( is => 'rw', isa => 'FileHandle' );
has 'java_pid'     => ( is => 'rw', isa => 'Int' );

sub BUILD {

    my ( $self, $params ) = @_;

    # try to download the ML-Process JAR file + other libraries and set their real absolute path
    # (assuming everything is downloaded into one subtree)
    foreach my $shared_file ( @{$ML_PROCESS_LIBRARIES} ) {
        Treex::Core::Resource::require_file_from_share( $ML_PROCESS_BASEDIR . $shared_file, 'the ML-Process tool block' );
    }
    $self->_set_ml_process_jar( Treex::Core::Resource::require_file_from_share( $self->ml_process_jar ) );
    $self->_set_model( Treex::Core::Resource::require_file_from_share( $self->model ) );

    # run ML-Process, loading the model
    my $mlprocess = File::Java->path_arg( $self->ml_process_jar );
    my $command   = 'java ' . ' -Xmx' . $self->memory
        . ' -cp ' . $mlprocess . ' en_deep.mlprocess.simple.Simple '
        . ' -v ' . $self->verbosity
        . ( $self->caching =~ m/^[0-9]+$/ ? ' -s ' : ' -a ' ) . $self->caching
        . ' -r '
        . ' ' . $self->model;

    log_info( "Running " . $command );

    $SIG{PIPE} = 'IGNORE';    # don't die if ML-Process gets killed
    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);

    $self->set_read_handle($read);
    $self->set_write_handle($write);
    $self->set_java_pid($pid);

    my $status = <$read>;     # wait for loading of all models
    log_fatal('ML-Process not loaded correctly') if ( $status !~ /^READY/ );

    return;
}

sub DEMOLISH {

    my ($self) = @_;

    # Close the ML-Process application
    close( $self->write_handle );
    close( $self->read_handle );
    ProcessUtils::safewaitpid( $self->java_pid );
    return;
}

# Classify a bunch of lines in ARFF headerless format, return results
sub classify {
    my ( $self, @data_lines ) = @_;
    my @results;

    # write the input ARFF lines
    foreach my $data_line (@data_lines) {
        $data_line .= "\n" if ( $data_line !~ /\n$/ );
        print { $self->write_handle } $data_line;
    }

    # this will force ML-Process to flush the output (even if caching is set differently)
    print { $self->write_handle } "\n";

    # read the results (same number of lines as the input -- will not block forever)
    my $read = $self->read_handle;
    foreach my $i ( 1 .. @data_lines ) {
        my $result = <$read>;
        push @results, $result;
    }

    return @results;
}

# Converts Treex error level to MLProcess verbosity (a bit skewed to the non-verbose side,
# so that MLProcess shows only warnings and errors if the Treex error_level is set to INFO)
sub _build_verbosity {
    my ($self) = @_;

    my $error_level = Treex::Core::Log::get_error_level();
    return List::MoreUtils::first_index { $_ eq $error_level } qw(FATAL WARN INFO DEBUG ALL);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::ML::MLProcess

=head1 DESCRIPTION



=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

