package Treex::Block::A2T::CS::SetFunctors;

use Moose;
use Treex::Common;
use Treex::Block::Write::ConllLike;
use File::Java;
use File::Temp ();
use Treex::Tools::IO::Arff;
use autodie;

extends 'Treex::Core::Block';

# ML-Process executable
has 'ml_process_jar' => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/personal/odusek/ml-process/ml-process.jar" );

# Amount of memory needed for Java VM
has 'memory' => ( is => 'ro', isa => 'Str', default => '1g' );

# files related to the trained model
has 'model_dir'         => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/personal/odusek/functors-model/" );
has 'model'             => ( is => 'ro', isa => 'Str', default => 'model.dat' );
has 'plan_template'     => ( is => 'ro', isa => 'Str', default => 'plan.template' );
has 'filtering_ff_data' => ( is => 'ro', isa => 'Str', default => 'ff-data.dat' );
has 'filtering_if_data' => ( is => 'ro', isa => 'Str', default => 'if-data.dat' );
has 'lang_conf'         => ( is => 'ro', isa => 'Str', default => 'st-cs.conf' );

# clean temp files after use ?
has 'cleanup_temp' => ( is => 'ro', isa => 'Int', default => 1 );

# temporary directory used by the process
has '_temp_dir' => ( is => 'ro', builder => '_create_temp_dir' );

# list of tempfiles used by the process
has '_tempfiles' => ( traits => ['Array'], is => 'ro', default => sub { [] } );

# functors loaded from the result of ML process, works as a FIFO (is first filled with the whole document, then subsequently emptied)
has '_functors' => ( traits => ['Array'], is => 'ro', default => sub { [] } );

override 'process_document' => sub {

    my ( $this, $document ) = @_;

    # print out data in pseudo-conll format for the ml-process program
    my $temp_conll = $this->_create_temp_file();

    log_info( "Writing the CoNLL-like data to " . $temp_conll );
    my $conll_out = Treex::Block::Write::ConllLike->new( to => $temp_conll->filename, language => 'cs' );
    $conll_out->process_document($document);

    # generate the plan file for ml-process
    my ( $plan, $out ) = $this->_generate_plan( $temp_conll->filename );

    # run the ml-process
    my $mlprocess = File::Java->path_arg( $this->ml_process_jar );
    my $command   = 'java '
        . ' -Xmx' . $this->memory()
        . ' -jar ' . $mlprocess
        . ' -d ' . $this->_temp_dir()
        . ( $this->cleanup_temp ? ' -l ' : '' )
        . ' ' . $plan
        . ' -v 4 ';
    log_info( "Running " . $command );
    system($command) == 0 or log_fatal("ML-Process not found or not working properly.");

    # parse the output file and store the results
    $this->_load_functors($out);

    # process all t-trees and fill them with functors
    super;
};

# this fills a t-tree with functors, which must be preloaded in $this->_functors
sub process_ttree {

    my ( $this, $root ) = @_;
    my @functors = @{ shift @{ $this->_functors } };           # always take results for the first tree, FIFO
    my @nodes = $root->get_descendants( { ordered => 1 } );    # same as for printing in Write::ConllLike

    if ( scalar(@nodes) != scalar(@functors) ) {
        log_fatal( "Expected " . scalar(@nodes) . " functors, got " . scalar(@functors) );
    }
    foreach my $node (@nodes) {
        $node->set_functor( shift @functors );
    }
    return;
}

# generate plan file for ml-process, return plan file and ARFF output file handle
sub _generate_plan {

    my ( $this, $temp_conll ) = @_;
    my $plan_file     = $this->_create_temp_file();
    my $temp_arff_out = $this->_create_temp_file();

    # load the plan template
    log_info( "Creating plan file " . $plan_file );
    my $plan_template = $this->_load_file_contents( $this->model_dir . $this->plan_template );

    # fill with relevant file names
    $plan_template = $this->_replace( $plan_template, "CONLL",     $temp_conll );
    $plan_template = $this->_replace( $plan_template, "ARFF-OUT",  $temp_arff_out->filename );
    $plan_template = $this->_replace( $plan_template, "FF-INFO",   $this->model_dir . $this->filtering_ff_data );
    $plan_template = $this->_replace( $plan_template, "IF-INFO",   $this->model_dir . $this->filtering_if_data );
    $plan_template = $this->_replace( $plan_template, "MODEL",     $this->model_dir . $this->model );
    $plan_template = $this->_replace( $plan_template, "LANG-CONF", $this->model_dir . $this->lang_conf );

    # replace the rest with temp files, don't care for their names
    $plan_template = $this->_replace_all($plan_template);

    # write the final plan
    $this->_write_file_contents( $plan_file, $plan_template );

    log_info( "Output will be to " . $temp_arff_out );
    return ( $plan_file, $temp_arff_out );
}

# create a new temporary directory
sub _create_temp_dir {
    my ($this) = @_;
    return File::Temp->newdir( CLEANUP => $this->cleanup_temp() );
}

# create a temporary file in our temporary directory, add it to the list of tempfiles
sub _create_temp_file {

    my ($this) = @_;

    my $tempfile = File::Temp->new( TEMPLATE => 'mlprocess-XXXX', UNLINK => $this->cleanup_temp(), DIR => $this->_temp_dir->dirname );
    push @{ $this->_tempfiles }, $tempfile;
    return $tempfile;
}

# Read the contents of a file (given name) to a string
sub _load_file_contents {
    my ( $this, $filename ) = @_;
    my $fh;
    open( $fh, '<:utf8', $filename );
    my @contents = <$fh>;
    close($fh);
    return join( "", @contents );
}

# Write a string to the given file (given open descriptor) and close it
sub _write_file_contents {
    my ( $this, $file, $contents ) = @_;
    print $file ($contents);
    close($file);
    return;
}

# Replace the given variable with the given string in the plan file template
sub _replace {
    my ( $this, $string, $var_name, $replacement ) = @_;

    $string =~ s/\|$var_name\|/$replacement/g;

    return $string;
}

# Replace all variables in the plan file template with temporary file names
sub _replace_all {
    my ( $this, $string ) = @_;

    while ( $string =~ m/\|([A-Za-z_-]+)\|/ ) {
        my $var      = $1;
        my $tempfile = $this->_create_temp_file();
        $string =~ s/\|$var\|/$tempfile/g;
    }

    return $string;
}

# Load the functors assigned by the ML process from the ARFF file
sub _load_functors {

    my ( $this, $arff_file ) = @_;
    my $loader = Treex::Tools::IO::Arff->new();
    my $data   = $loader->load_arff( $arff_file->filename );

    my $sentence;
    my $sent_id = 1;

    for my $rec ( @{ $data->{records} } ) {

        if ( $rec->{'sent-id'} != $sent_id ) {                 # move to next sentence
            push @{ $this->_functors }, $sentence;
            $sentence = [];
            $sent_id++;
        }
        push @{$sentence}, $rec->{'deprel'};
    }
    push @{ $this->_functors }, $sentence;
    return;
}

1;

__END__

=head1 Treex::Block::A2T::CS::SetFunctors

Sets functors in tectogrammatical trees using a pre-trained machine learning model (logistic regression, SVM etc.)
via the ML-Process Java executable with WEKA integration.

=head2 Parameters

All of the file paths have their default value set:

=over

=item cleanup_temp

Delete all temporary files after use? (default: 1, set to 0 if you want to keep the temporary files)

=item ml_process_jar

Path to the ML-Process executable JAR file.

=item memory

The maximum amount of memory reserved for the Java VM.

=item model_dir

Pre-trained model directory.

=item model

Name of the trained model file.

=item plan_template

Name of the ML-Process plan file template.

=item filtering_ff_data 

Name of the feature filtering information file.

=item filtering_if_data

Name of the feature removal information file.

=item lang_conf

Name of the feature generation configuration file.

=back

=head2 TODO

Possibly could be made language independent, only with different models for different languages. 

=cut

# Copyright 2011 Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

