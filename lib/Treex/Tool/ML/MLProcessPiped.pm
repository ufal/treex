package Treex::Tool::ML::MLProcessPiped;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::IO::Arff;
use Treex::Tool::ProcessUtils;

# The base directory for the ML-Process tool
Readonly my $ML_PROCESS_BASEDIR => 'installed_tools/ml-process/';

# All files the ML-Process tool needs for its work (except the executable JAR)
Readonly my $ML_PROCESS_LIBRARIES => [
    'lib/google-collect-1.0.jar',
    'lib/java-getopt-1.0.13.jar',
    'lib/liblinear-1.8.jar',
    'lib/lpsolve55j.jar',
    'dll_32/liblpsolve55.so',
    'dll_32/liblpsolve55j.so',
    'dll_64/liblpsolve55.so',
    'dll_64/liblpsolve55j.so',
    'lib/weka-3.7.6.jar',
    'lib/weka-liblinear-1.8.jar',
    'lib/chisquared-attr-eval-1.0.2.jar',
    'lib/significance-attr-eval-1.0.1.jar',
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

# Require a list of available model keys on startup?
has 'require_list_of_models' => ( is => 'ro', isa => 'Bool', default => 0 );

# ML-Process slave application controls (bipipe handles, application PID)
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );
has '_java_pid'     => ( is => 'rw', isa => 'Int' );

# List of model keys (available only if require_list_of_models is true)
has 'models_list' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

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
    my $mlprocess = $self->ml_process_jar;
    my @params =  
        ('java', '-Xmx' . $self->memory,
        '-cp', $mlprocess, 'en_deep.mlprocess.simple.Simple',
        '-v', $self->verbosity,
        '-c', 'UTF-8',
        ( $self->caching =~ m/^[0-9]+$/ ? '-s' : '-a' ), $self->caching,
        '-r');
        
    if ($self->require_list_of_models) { 
      push @params, '-l';
    }

    push @params, $self->model;

    log_info( "Running @params");

    $SIG{PIPE} = 'IGNORE';    # don't die if ML-Process gets killed
    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe_noshell(":utf8", @params);

    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_java_pid($pid);

    my $status = <$read>;     # wait for loading of all models
    log_fatal('ML-Process not loaded correctly') if ( ($status || '') !~ /^READY/ );
    
    if ($self->require_list_of_models){
        my $models_list = <$read>;
        chomp $models_list;
        foreach my $model_key (split / /, $models_list){
            $self->models_list->{$model_key} = 1;
        } 
    }
    return;
}

sub DEMOLISH {

    my ($self) = @_;

    # Close the ML-Process application
    close( $self->_write_handle );
    close( $self->_read_handle );
    kill(9, $self->_java_pid); #Needed on Windows
    Treex::Tool::ProcessUtils::safewaitpid( $self->_java_pid );
    return;
}

# Classify a bunch of lines in ARFF headerless format, return results
sub classify {
    my ( $self, @data_lines ) = @_;
    my @results;

    # write the input ARFF lines
    foreach my $data_line (@data_lines) {
        $data_line .= "\n" if ( $data_line !~ /\n$/ );
        print { $self->_write_handle } $data_line;
    }

    # this will force ML-Process to flush the output (even if caching is set differently)
    print { $self->_write_handle } "\n";

    # read the results (same number of lines as the input -- will not block forever)
    my $read = $self->_read_handle;
    foreach my $i ( 1 .. @data_lines ) {
        my $result = <$read>;
        # die if ML-Process ends prematurely, without producing the desired number of outputs
        log_fatal "Not enough results from ML-Process." if ( !defined($result) );
        $result =~ s/\r?\n$//; # remove end-of-line characters
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

Treex::Tool::ML::MLProcessPiped

=head1 SYNOPSIS

  # model.dat.gz contains a model for classifying the standard "Iris" data set
  my $mlprocess = Treex::Tool::ML::MLProcessPiped->new( { model => 'model.dat.gz' } );
 
  # prepare input data
  my @arff_data = <<END;
  5.1,3.5,1.4,0.2,?
  4.9,3.0,1.4,0.2,?
  4.7,3.2,1.3,0.2,?
  7.0,3.2,4.7,1.4,?
  6.4,3.2,4.5,1.5,?
  5.9,3.0,5.1,1.8,?
  END 
  
  my @results = $mlprocess->classify(@arff_data);
  
  # prints 'Iris-setosa Iris-setosa Iris-setosa Iris-versicolor Iris-versicolor Iris-virginica' 
  # if the classifier is sane
  print join " ", @results;
  

=head1 DESCRIPTION

A wrapper for the ML-Process "Simple" WEKA wrapper, which provides various machine learning
classifiers. 

It uses L<Treex::Tool::ProcessUtils::Bipipe> to establish a piped connection (all models are loaded on startup), 
then feeds given ARFF data lines to the ML-Process executable and retrieves its output.

The ML-Process JAR file, along with all needed dependencies, must be installed in the Treex shared
directory (will be downloaded via L<Treex::Core::Resource::require_file_from_share()> if not available). 

=head1 PARAMETERS

=over

=item memory

Amount of memory for the Java VM running the ML-Process executable (default: 1g).

=item model

Path to the packed model file.

=item verbosity

Verbosity of the ML-Process library (on the error output). Set using the Treex error level by default.

=item caching

Instances caching settings for the ML-Process library. Should be either a number (1 = no caching, 10 = default),
or a name of a feature whose change should trigger flushing the ML-Process output.

=back

=head1 METHODS

=over

=item @arff_output = classify(@arff_input);

Given ARFF input data lines, this passes them to the ML-Process executable and returns the results
(as ARFF data lines to be parsed, excluding the final "\n" characters). 

=back

=head1 SEE ALSO

L<Treex::Tool::ML::MLProcessBlockPiped>

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

