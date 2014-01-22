package Treex::Tool::ML::MLProcessBlockPiped;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ML::MLProcessPiped;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::ArffWriting';

#
# DATA
#

# Amount of memory needed for ML-Process Java VM
has 'memory' => ( is => 'ro', isa => 'Str', default => '1g' );

# Path to the packed model data file
has 'model' => ( is => 'ro', isa => 'Str', required => 1 );

# Override the default treex error level for ML-Process (0 = nothing, 4 = debug)
has 'verbosity' => ( is => 'ro', isa => 'Maybe[Int]' );

# Pipe caching settings (default: one sentence at a time)
has 'caching' => ( is => 'ro', isa => 'Str', default => 'sent_id' );

# Require a list of available model keys on startup?
has 'require_list_of_models' => ( is => 'ro', isa => 'Bool', default => 0 );

# The ML-Process underlying executable
has '_mlprocess' => ( is => 'rw', isa => 'Maybe[Treex::Tool::ML::MLProcessPiped]' );

# The names of the ML-Process results attributes
has 'input_attrib_names' => ( is => 'ro', isa => 'ArrayRef' );

# Config file handling for output features
has '+config_file' => ( builder => '_build_config_file', lazy_build => 1 );

has 'features_config' => ( is => 'ro', isa => 'Str' );

# ARFF reader for ML-Process results, incl. config file handling
has '_arff_reader' => ( is => 'ro', builder => '_init_arff_reader', lazy_build => 1 );

has 'results_config_file' => ( is => 'ro', isa => 'Str', builder => '_build_results_config_file', lazy_build => 1 );

has 'results_config' => ( is => 'ro', isa => 'Str' );

#
# METHODS
#

# Read configuration files regarding attributes
sub BUILDARGS {

    my ( $class, $args ) = @_;

    if ( $args->{input_config_file} ) {
        $args->{input_attrib_names} = _read_input_config_file( $args->{input_config_file} );
    }

    return $args;
}

# Get the ML-Process executable up and running, load the models
sub process_start {

    my ($self) = @_;

    my $params = {
        model                  => $self->model,
        memory                 => $self->memory,
        caching                => $self->caching,
        require_list_of_models => $self->require_list_of_models,
    };
    $params->{verbosity} = $self->verbosity if ( $self->verbosity );

    my $mlprocess = Treex::Tool::ML::MLProcessPiped->new($params);
    $self->_set_mlprocess($mlprocess);

    return;
}

# Build ARFF output config file name from the features_config parameter
sub _build_config_file {

    my ($self) = @_;
    return if ( !$self->features_config );
    return Treex::Core::Resource::require_file_from_share( $self->features_config );
}

# Build ARFF input config file name from the features_config parameter
sub _build_results_config_file {

    my ($self) = @_;
    return if ( !$self->results_config );
    return Treex::Core::Resource::require_file_from_share( $self->results_config );
}

# Read config file with names of the input (result) attributes
sub _read_input_config_file {

    my ($file_name) = @_;

    my $cfg = YAML::Tiny->read($file_name);
    log_fatal( 'Cannot read configuration file ' . $file_name ) if ( !$cfg );

    $cfg = $cfg->[0];
    my @labels = map { $_->{label} } @{ $cfg->{attributes} };
    return \@labels;
}

# Initialize the module reading the ARFF input (results)
sub _init_arff_reader {

    my ($self) = @_;
    my $arff = Treex::Tool::IO::Arff->new();

    $arff->relation->{relation_name} = 'RELATION';

    my $j = 0;

    foreach my $attr ( @{ $self->input_attrib_names } ) {

        my $attr_entry = {
            'attribute_name' => $attr,
            'attribute_type' => undef,    # ignore attribute types
        };

        push @{ $arff->relation->{attributes} }, $attr_entry;
    }

    return $arff;
}

# Classify a given bunch of nodes, return the result as an array of hashes (attribute - value; attributes should include
# the class attribute)
sub classify_nodes {

    my ( $self, @nodes ) = @_;
    return if ( !@nodes );

    # Push the nodes to the output ARFF buffer and obtain the ARFF output
    my $sent_id = $nodes[0]->get_document->file_stem . $nodes[0]->get_document->file_number . '##' . $nodes[0]->id;
    map { $self->_push_node_to_output( $_, $sent_id, $_->ord ) } @nodes;
    my @data_lines = $self->_arff_writer->get_data_lines( $self->_arff_writer->relation );
    $self->_arff_writer->clear_data();

    # have the data lines classified, parse the input resulting data ARFF lines and return the final array of hashes
    my $line_ctr = 1;
    map { $self->_arff_reader->add_data_line( $line_ctr++, $_ ) } $self->_mlprocess->classify(@data_lines);

    my @results = @{ $self->_arff_reader->relation->{records} };
    $self->_arff_reader->clear_data();
    return @results;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::MLProcessBlockPiped

=head1 DESCRIPTION

A base class for all blocks that just use the ML-Process library for classification,
handling the ARFF I/O communication with the ML-Process library. It provides the means
of configuring the needed ARFF output (i.e. classification features to ML-Process) and 
input (i.e. predicted classes from ML-Process) and classifying a given set of nodes
(which is considered to be a sentence by default).

=head1 PARAMETERS 

The following parameters are designated to be overridden in derived blocks, but are 
open to be entered directly by the user in the scenario:

=over

=item model

Path to the packed model file, within the Treex shared directory (will be downloaded using
L<Treex::Core::Resource::require_file_from_share()> if not available).

=item caching

Sets the chaching of the items to be classified -- specify either a number (1 = no caching,
10 = per ten items etc.) or a name of a feature (if the value of this feature changes, the
buffer is flushed). This is set to C<sent_id> by default, i.e. each sentence is classified
as a whole. 

=item features_config

Path to the ARFF output configuration file (i.e. which features are passed to the classifier),
within the Treex shared directory (will be downloaded using 
L<Treex::Core::Resource::require_file_from_share()>). 

This controls the setting of the C<config_file> attribute of the 
L<Treex::Block::Write::ArffWriting> role; setting the C<config_file> directly overrides the 
shared directory resolving. See L<Treex::Block::Write::Arff> for the config file format.

=item input_attrib_names

This should contain the names of features that are given back from the classifier as the result.
The format is a space-or-comma-separated list; usually it will be only the one class attribute.

=item results_config

This specifies a configuration file that contains the list of features given back from the 
classifier (i.e. may be used instead of the direct setting in C<input_attrib_names>). 

The file is looked up in the Treex shared directory (and will be downloaded using 
L<Treex::Core::Resource::require_file_from_share()> if not available). If you want to 
override this behavior using a direct path, set the C<results_config_file> parameter instead.

=back

The following parameters are left to control the behavior of the ML-Process library directly:

=over

=item verbosity

This sets the verbosity of the library, from 0 (none) to 4 (most verbose). A default setting
is inferred from the Treex error level (L<Treex::Core::Log::get_error_level>). 

=item memory

Amount of memory available for the Java Virtual Machine (default: 1g).  

=back 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
