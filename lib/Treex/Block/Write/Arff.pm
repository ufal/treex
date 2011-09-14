package Treex::Block::Write::Arff;

use Moose;
use Treex::Core::Common;
use Treex::Tool::IO::Arff;
use YAML::Tiny;
use autodie;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

#
# DATA
#

has '+language' => ( required => 1 );

# ARFF data file structure as it's set in Treex::Tool::IO::Arff
has '_arff' => ( is => 'ro', builder => '_init_arff', lazy_build => 1 );

# Current sentence ID, starting with 1
has '_sent_id' => ( is => 'ro', isa => 'Int', writer => '_set_sent_id', default => 1 );

# Were the ARFF file headers already printed ?
has '_headers_printed' => ( is => 'ro', isa => 'Bool', writer => '_set_headers_printed', default => 0 );

# Override the default data type settings
has 'force_types' => ( is => 'ro', isa => 'HashRef', builder => '_build_force_types', lazy_build => 1 );

# Override output attribute names
has 'output_attrib_names' => ( is => 'ro', isa => 'HashRef', builder => '_build_output_attrib_names', lazy_build => 1 );

# Read configuration from a file
has 'config_file' => ( is => 'ro', isa => 'Str' );

#
# METHODS
#

# Try to read the configuration file, if applicable, and set the returned values
sub BUILDARGS {

    my ( $class, $params ) = @_;

    if ( $params->{config_file} ) {
        ( $params->{attributes}, $params->{output_attrib_names}, $params->{force_types}, $params->{modifier_config} ) =
            _read_config_file( $params->{config_file} );
    }

    return $params;
}

# YAML configuration file reader
sub _read_config_file {

    my ($file_name) = @_;

    my $cfg = YAML::Tiny->read($file_name);
    log_fatal( 'Cannot read configuration file ' . $file_name ) if ( !$cfg );

    $cfg = $cfg->[0];
    my @sources = map { $_->{source} } @{ $cfg->{attributes} };
    my %labels  = map { $_->{source} => $_->{label} ? [ split( /[\s,]\+/, $_->{label} ) ] : undef } @{ $cfg->{attributes} };
    my %types   = map { $_->{source} => $_->{type} ? [ split( /[\s,]\+/, $_->{type} ) ] : undef } @{ $cfg->{attributes} };

    return ( \@sources, \%labels, \%types, $cfg->{modifier_config} );
}

# Build a hashref from datatype override settings
sub _build_force_types {

    my ($self) = @_;
    return _parse_hashref( 'force_types', $self->force_types );
}

sub _build_output_attrib_names {
    my ($self) = @_;
    return _parse_hashref( 'output_attrib_names', $self->output_attrib_names );
}

# Apply all attribute name overrides as specified in output_attrib_names
around '_set_output_attrib' => sub {

    my ( $set, $self, $output_attrib ) = @_;
    
    my $over = $self->output_attrib_names;
    my $orig = $self->_attrib_io;
    my %ot   = ();
    
    # build an override table: original name => overridden name
    foreach my $in_attr ( keys %{$orig} ) {
        foreach my $i ( 0 .. @{ $orig->{$in_attr} } - 1 ) {
            $ot{ $orig->{$in_attr}->[$i] } = $over->{$in_attr} ? $over->{$in_attr}->[$i] : $orig->{$in_attr}->[$i];
        }
    }
    
    # apply the override table
    $output_attrib = [ map { $ot{$_} } @{$output_attrib} ];
    
    log_info( join ' ' , @{ $output_attrib } );

    $self->$set($output_attrib);
};

override 'process_document' => sub {

    my $self = shift;
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    # _process_tree called here: store data
    super;

    if ( !$self->_headers_printed ) {
        $self->_arff->prepare_headers( $self->_arff->relation, 0, 1 );
    }

    # print out the data
    $self->_arff->save_arff( $self->_arff->relation, $self->_file_handle, !$self->_headers_printed );

    if ( !$self->_headers_printed ) {
        $self->_set_headers_printed(1);
    }

    # clear the data in memory
    $self->_arff->relation->{records}           = [];
    $self->_arff->relation->{data_record_count} = 0;
};

# Store node data from one tree as ARFF
sub _process_tree {

    my ( $self, $tree ) = @_;

    # Get all needed informations for each node and save it to the ARFF storage
    my @nodes = $tree->get_descendants( { ordered => 1 } );
    my $word_id = 1;
    foreach my $node (@nodes) {

        my $info = $self->_get_info_hash($node);

        $info->{sent_id} = $self->_sent_id;
        $info->{word_id} = $word_id;

        push( @{ $self->_arff->relation->{records} }, $info );
        $word_id++;
    }

    $self->_set_sent_id( $self->_sent_id + 1 );
    return 1;
}

# Initialize the ARFF reader
sub _init_arff {

    my ($self) = @_;
    my $arff = Treex::Tool::IO::Arff->new();

    $arff->relation->{relation_name} = $self->to;
    push( @{ $arff->relation->{attributes} }, { attribute_name => 'sent_id' } );
    push( @{ $arff->relation->{attributes} }, { attribute_name => 'word_id' } );

    my $j = 0;

    foreach my $attr ( @{ $self->attributes } ) {

        foreach my $i ( 0 .. @{ $self->_attrib_io->{$attr} } - 1 ) {

            my $attr_entry = {
                'attribute_name' => $self->_output_attrib->[ $j++ ],
                'attribute_type' => ( $self->force_types->{$attr} ? $self->force_types->{$attr}->[$i] : undef )
            };

            push @{ $arff->relation->{attributes} }, $attr_entry;
        }
    }

    return $arff;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::Arff

=head1 DESCRIPTION

Print out the desired attributes of all trees on the specified layer in the input documents as an 
L<ARFF file|http://www.cs.waikato.ac.nz/~ml/weka/arff.html>
(used by the L<WEKA|http://www.cs.waikato.ac.nz/ml/weka/> machine learning environment). 

Additional word and sentence IDs starting with (1,1) are assigned to each node on the output. The word IDs correspond
with the order of the nodes. All attributes that are not numeric are considered C<STRING> in the output ARFF file 
specification.

=head1 PARAMETERS

=over

=item C<language>

Specification of the language zone for the trees to be processed. This parameter is required.

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-separated list of attributes (relating to the tree nodes on the specified layer) to be processed. 
This parameter is required.

For multiple-valued attributes (lists), dereferencing and text modifiers, please see 
L<Treex::Block::Write::LayerAttributes>. 

=item C<output_attrib_names>

A hash reference containing the original attribute names as keys and their desired output names in the ARFF file
as values (as array references, since there may be several output attributes resulting from one source, due
to attribute modifiers, see L<Treex::Block::Write::LayerAttributes>).

=item C<modifier_config> 

See L<Treex::Block::Write::LayerAttributes>.

=item C<force_types>

Override default data type (which is 'NUMERIC', if only numeric values are used, and 'STRING' otherwise). Should be
passed as a hash reference, analogous to C<output_attrib_names>.  

=item C<config_file>

The name of a YAML containing the settings for C<attributes>, C<output_attrib_names>, C<modifier_config> and 
C<force_types>, in the following format:

    ---
    attributes:
        - source: "data source, e.g. a/lex.rf->tag (attributes member)" 
          label:  "the name override (output_attrib_names member)"
          type:   "data type override (force_types member)"

        - source: "another data source, this time no overrides"

        - source: "Modifier(another data)"
          label:  output_label_1, output_label_2, output_label_3

    # a commentary        
    modifier_config:

        ModifierClassName1:
            setting1: value
            setting2: value

        ModifierClassName2:
            - value1
            - value2
   ...

Please note that some data source names, as well as new labels and type definitions, need to be enclosed
in quotes. 
    
=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 TODO


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
