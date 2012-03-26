package Treex::Block::Write::Arff;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Write::LayerParameterized';
with 'Treex::Block::Write::ArffWriting';

#
# DATA
#

has '+extension' => ( default => '.arff' );

has '+language' => ( required => 1 );

#
# METHODS
#

# Store node data from one tree as ARFF in a file
sub _process_tree {

    my ( $self, $tree ) = @_;

    # Get all needed informations for each node and save it to the ARFF storage
    my @nodes   = $tree->get_descendants( { ordered => 1 } );
    my $word_id = 1;
    my $sent_id = $tree->get_document->file_stem . $tree->get_document->file_number . '##' . $tree->id;

    foreach my $node (@nodes) {
        $self->_push_node_to_output( $node, $sent_id, $word_id++ );
    }

    # prepare the headers for printing, if not done
    if ( !$self->_headers_printed ) {
        $self->_arff_writer->prepare_headers( $self->_arff_writer->relation, 0, 1 );
    }

    # print out the data
    $self->_arff_writer->save_arff( $self->_arff_writer->relation, $self->_file_handle, !$self->_headers_printed );

    if ( !$self->_headers_printed ) {
        $self->_set_headers_printed(1);
    }

    # clear the data in memory
    $self->_arff_writer->relation->{records}           = [];
    $self->_arff_writer->relation->{data_record_count} = 0;

    return 1;
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

Additional word and sentence IDs  are assigned to each node on the output. The sentence IDs are a concatenation of 
the file name and tree root IDs, The word IDs correspond with the order of the nodes. All attributes are considered 
C<STRING> by default in the output ARFF file specification, unless instructed otherwise in C<force_types>
or the configuration file.

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

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
