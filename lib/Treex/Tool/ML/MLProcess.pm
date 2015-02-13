package Treex::Tool::ML::MLProcess;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use File::Temp ();
use Treex::Tool::IO::Arff;
use autodie;

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

# ML-Process plan template file
has 'plan_template' => ( is => 'rw', isa => 'Str', required => 1 );

# clean temp files after use ?
has 'cleanup_temp' => ( is => 'rw', isa => 'Int', default => 1 );

# the data file where the input to the whole process should be placed
has 'input_data_file' => ( is => 'rw', isa => 'FileHandle', builder => '_create_input_file', lazy_build => 1 );

# the data file from which the output of the process is read
has 'output_data_file' => ( is => 'rw', isa => 'FileHandle', builder => '_create_output_file', lazy_build => 1 );

# temporary directory used by the process
has '_temp_dir' => ( is => 'ro', builder => '_create_temp_dir' );

# list of tempfiles used by the process
has '_tempfiles' => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );

sub BUILD {
    my ( $self, $params ) = @_;

    # try to download the ML-Process JAR file + other libraries and set their real absolute path
    # (assuming everything is downloaded into one subtree)
    foreach my $shared_file ( @{$ML_PROCESS_LIBRARIES} ) {
        Treex::Core::Resource::require_file_from_share( $ML_PROCESS_BASEDIR . $shared_file, 'the ML-Process tool block' );
    }
    $self->_set_ml_process_jar( Treex::Core::Resource::require_file_from_share( $self->ml_process_jar ) );
}

sub run {

    my ( $self, $parameters ) = @_;

    my $plan_file = $self->_create_temp_file('plan');

    # load the plan template
    log_info( "Creating plan file " . $plan_file );

    my $plan = $self->_load_file_contents( $self->plan_template );

    # replace input and output variables with input and output file names
    $plan = $self->_replace( $plan, 'INPUT',  $self->input_data_file->filename );
    $plan = $self->_replace( $plan, 'OUTPUT', $self->output_data_file->filename );

    # replace all decided patterns
    while ( my ( $parameter, $file ) = each( %{$parameters} ) ) {
        $plan = $self->_replace( $plan, $parameter, $file );
    }

    # replace the rest with temp files, don't care for their names
    $plan = $self->_replace_all($plan);

    # write the final plan
    $self->_write_file_contents( $plan_file, $plan );

    # run the ml-process
    my $mlprocess = $self->ml_process_jar;
    my $command   = 'java '
        . ' -Xmx' . $self->memory
        . ' -jar ' . $mlprocess
        . ' -d ' . $self->_temp_dir()
        . ( $self->cleanup_temp ? ' -l ' : '' )
        . ' -s UTF-8 '
        . ' ' . $plan_file
        . ' -v ' . $self->verbosity . ' ';

    log_info( "Running " . $command );
    my $rv = system($command);
    log_fatal("ML-Process not found or not working properly. Return value: $rv.") if ( $rv != 0 );
}

# Load the given attribute classified by the process from the ARFF file
sub load_results {

    my ( $self, $class_attr ) = @_;
    my $loader = Treex::Tool::IO::Arff->new();
    my $data   = $loader->load_arff( $self->output_data_file->filename );

    my $out = [];

    for my $rec ( @{ $data->{records} } ) {
        push @{$out}, $rec->{$class_attr};
    }
    return $out;
}

# create a new temporary directory
sub _create_temp_dir {
    my ($self) = @_;
    return File::Temp->newdir( CLEANUP => $self->cleanup_temp() );
}

# create a temporary file in our temporary directory, add it to the list of tempfiles
sub _create_temp_file {

    my ( $self, $name ) = @_;

    $name =~ s/[^A-Za-z0-9_-]//g;
    $name = lc($name);

    my $tempfile = File::Temp->new(
        TEMPLATE => 'mlprocess-' . $name . '-XXXX',
        UNLINK   => $self->cleanup_temp(),
        DIR      => $self->_temp_dir->dirname
    );
    push @{ $self->_tempfiles }, $tempfile;
    return $tempfile;
}

# create the input temporary file
sub _create_input_file {
    my ($self) = @_;
    return $self->_create_temp_file('input');
}

# create the output temporary file
sub _create_output_file {
    my ($self) = @_;
    return $self->_create_temp_file('output');
}

# Replace the given variable with the given string in the plan file template
sub _replace {
    my ( $self, $string, $var_name, $replacement ) = @_;

    $var_name =~ s/([|\[\]])/\\$1/g;               # TODO capture all regexp special characters
    $string   =~ s/\|$var_name\|/$replacement/g;

    return $string;
}

# Replace all variables in the plan file template with temporary file names
sub _replace_all {
    my ( $self, $string ) = @_;

    while ( $string =~ m/\|([A-Za-z_-]+)\|/ ) {
        my $var      = $1;
        my $tempfile = $self->_create_temp_file($var);
        $string =~ s/\|$var\|/$tempfile/g;
    }

    return $string;
}

# Read the contents of a file (given name) to a string
sub _load_file_contents {
    my ( $self, $filename ) = @_;
    my $fh;
    open( $fh, '<:utf8', $filename );
    my @contents = <$fh>;
    close($fh);
    return join( "", @contents );
}

# Write a string to the given file (given open descriptor) and close it
sub _write_file_contents {
    my ( $self, $file, $contents ) = @_;
    print $file ($contents);
    close($file);
    return;
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

=head1 SYNOPSIS

    my $mlprocess = Treex::Tool::ML::MLProcess->new( plan_template => $plan_template_file ); # initialization

    my $input = $mlprocess->input_data_file; # retrieve the the temporary input file handle

    # ... now write the input data into the temporary input file ...

    $mlprocess->run( {  "MODEL" => $model_file } ); # replace any variables with given names

    $results = $self->load_results( 'class-attr');   # retrieve the results (as a reference to array of class attribute values)


=head1 DESCRIPTION

A simple wrapper for the L<ML-Process|http://code.google.com/p/en-deep/> Java machine learning environment 
with l<WEKA|http://www.cs.waikato.ac.nz/ml/weka/> integration.

The ML-Process executable must be run with a process plan. Here, we assume the process is run in a temporary 
directory and intermediate files do not matter -- for each run, a plan template is used where some variables 
(enclosed in C<|> characters) are replaced with true file names (mostly temporary files just for this run).

Two variable names are reserved -- C<|INPUT|> and C<|OUTPUT|>. They contain the specification where the input
and output files of the whole process are. The input file must be written by the calling block, the output file 
may be parsed using C<load_results> and the class attribute for each sentence retrieved. 

=head1 PARAMETERS

=over

=item cleanup_temp

Delete all temporary files after use? (default: 1, set to 0 if you want to keep the temporary files)

=item ml_process_jar

Path to the ML-Process executable JAR file within the shared directory (the default location is pre-set).

=item memory

The maximum amount of memory reserved for the Java VM (default: 1G).

=item plan_template

Name of the ML-Process plan file template (required).

=item input_data_file

Returns the handle for the temporary file where the input to the scenario is to be expected.

=item output_data_file

Returns the handle for the temporary file where the output of the scenario is to be found.

=back

=head1 METHODS 

=over

=item $self->run( \%variables )

Run the plan template with the variables substituted for the given file names.

=item $self->load_results( $class_attr )

Loads the results of the last scenario run (with the givenclass attribute) and returns them as a reference to 
an array of values for all instances in the input file.

=back

=head1 BUGS

The used temporary directory doesn't get deleted at the end, no idea why.  

=cut

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

