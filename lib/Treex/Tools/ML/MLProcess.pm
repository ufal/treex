package Treex::Tools::ML::MLProcess;

use Moose;
use Treex::Core::Common;
use File::Java;
use File::Temp ();
use autodie;

# ML-Process executable
has 'ml_process_jar' => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/personal/odusek/ml-process/ml-process.jar" );

# Amount of memory needed for Java VM
has 'memory' => ( is => 'ro', isa => 'Str', default => '1g' );

# ML-Process plan template file
has 'plan_template' => ( is => 'rw', isa => 'Str', required => 1 );

# clean temp files after use ?
has 'cleanup_temp' => ( is => 'rw', isa => 'Int', default => 1 );

# temporary directory used by the process
has '_temp_dir' => ( is => 'ro', builder => '_create_temp_dir' );

# list of tempfiles used by the process
has '_tempfiles' => ( traits => ['Array'], is => 'ro', default => sub { [] } );

sub run {

    my ( $self, $parameters ) = @_;

    my $plan_file = $self->create_temp_file();

    # load the plan template
    log_info( "Creating plan file " . $plan_file );
    my $plan = $self->_load_file_contents( $self->plan_template );

    # replace all decided patterns
    while ( my ( $parameter, $file ) = each( %{$parameters} ) ) {
        $plan = $self->_replace( $plan, $parameter, $file );
    }

    # replace the rest with temp files, don't care for their names
    $plan = $self->_replace_all($plan);

    # write the final plan
    $self->_write_file_contents( $plan_file, $plan );

    # run the ml-process
    my $mlprocess = File::Java->path_arg( $self->ml_process_jar );
    my $command   = 'java '
        . ' -Xmx' . $self->memory()
        . ' -jar ' . $mlprocess
        . ' -d ' . $self->_temp_dir()
        . ( $self->cleanup_temp ? ' -l ' : '' )
        . ' ' . $plan_file
        . ' -v 4 ';

    log_info( "Running " . $command );
    system($command) == 0 or log_fatal("ML-Process not found or not working properly.");
}

# create a new temporary directory
sub _create_temp_dir {
    my ($self) = @_;
    return File::Temp->newdir( CLEANUP => $self->cleanup_temp() );
}

# create a temporary file in our temporary directory, add it to the list of tempfiles
sub create_temp_file {

    my ($self) = @_;

    my $tempfile = File::Temp->new( TEMPLATE => 'mlprocess-XXXX', UNLINK => $self->cleanup_temp(), DIR => $self->_temp_dir->dirname );
    push @{ $self->_tempfiles }, $tempfile;
    return $tempfile;
}

# Replace the given variable with the given string in the plan file template
sub _replace {
    my ( $self, $string, $var_name, $replacement ) = @_;

    $string =~ s/\|$var_name\|/$replacement/g;

    return $string;
}

# Replace all variables in the plan file template with temporary file names
sub _replace_all {
    my ( $self, $string ) = @_;

    while ( $string =~ m/\|([A-Za-z_-]+)\|/ ) {
        my $var      = $1;
        my $tempfile = $self->create_temp_file();
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

1;

__END__

=head1 Treex::Block::ML::MLProcess

A simple wrapper for the L<ML-Process|http://code.google.com/p/en-deep/> Java machine learning environment 
with l<WEKA|http://www.cs.waikato.ac.nz/ml/weka/> integration.

The ML-Process executable must be run with a process plan. Here, we assume the process is run in a temporary 
directory and intermediate files do not matter -- for each run, a plan template is used where some variables 
(enclosed in C<|> characters) are replaced with true file names (mostly temporary files just for this run).

=head2 Parameters

=over

=item cleanup_temp

Delete all temporary files after use? (default: 1, set to 0 if you want to keep the temporary files)

=item ml_process_jar

Path to the ML-Process executable JAR file (default location is pre-set).

=item memory

The maximum amount of memory reserved for the Java VM (default: 1G).

=item plan_template

Name of the ML-Process plan file template (required).

=back

=head2 BUGS

The used temporary directory doesn't get deleted at the end, no idea why.  

=cut

# Copyright 2011 Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

