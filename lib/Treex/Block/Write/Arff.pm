package Treex::Block::Write::Arff;

use Moose;
use Treex::Core::Common;
use Treex::Tools::IO::Arff;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

#
# DATA
#

has '+language' => ( required => 1 );

# ARFF data file structure as it's set in Treex::Tools::IO::Arff
has '_arff' => (
    is         => 'ro',
    builder    => '_init_arff',
    lazy_build => 1
);

# Current sentence ID, starting with 1
has '_sent_id' => (
    is      => 'ro',
    isa     => 'Int',
    writer  => '_set_sent_id',
    default => 1
);

# Were the ARFF file headers already printed ?
has '_headers_printed' => (
    is      => 'ro',
    isa     => 'Bool',
    writer  => '_set_headers_printed',
    default => 0
);

# List of attributes to dereference
has 'deref_attrib' => (
    isa     => 'Str',
    is      => 'ro',
    default => ''
);

# Parsed list of attributes to dereference, constructed from the deref_attrib parameter
has '_deref_attrib_list' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    builder    => '_build_deref_attrib_list',
    lazy_build => 1
);

#
# METHODS
#

override 'process_document' => sub {

    my $self = shift;
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    super;    # _process_tree called here, store data

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

        my $info = $self->_get_node_info($node);
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
    my $arff = Treex::Tools::IO::Arff->new();

    $arff->relation->{relation_name} = $self->to;
    push( @{ $arff->relation->{attributes} }, { attribute_name => 'sent_id' } );
    push( @{ $arff->relation->{attributes} }, { attribute_name => 'word_id' } );

    # node attributes
    foreach my $attrib ( @{ $self->_attrib_list } ) {
        push( @{ $arff->relation->{attributes} }, { attribute_name => $attrib } );
    }

    # referenced attributes
    foreach my $deref ( @{ $self->_deref_attrib_list } ) {
        foreach my $attrib ( @{ $deref->{attr} } ) {
            push( @{ $arff->relation->{attributes} }, { attribute_name => $deref->{name} . '-' . $attrib } );
        }
    }

    return $arff;
}

# Parse the attribute list given in parameters.
sub _build_deref_attrib_list {
    my ($self) = @_;

    return {} if !$self->deref_attrib;

    my @list = split /\s*,\s*/, $self->deref_attrib;
    my @derefs;
    foreach my $deref (@list) {
        my ( $name, $attrs ) = split /\s*:\s*/, $deref;
        my @attr_list = split /\s+/, $attrs;

        push @derefs, { name => $name, attr => \@attr_list };
    }
    return \@derefs;
}

# Retrieve all the information needed for the conversion of each node and store it as a hash.
sub _get_node_info {

    my ( $self, $node ) = @_;
    my %info;

    foreach my $attrib ( @{ $self->_attrib_list } ) {

        if ( $attrib eq 'head' ) {
            $info{head} = $node->get_parent()->get_attr('ord');
        }
        else {
            $info{$attrib} = $node->get_attr($attrib);
        }
    }

    foreach my $deref ( @{ $self->_deref_attrib_list } ) {
        $self->_get_deref_attribs( $node, \%info, $deref->{name}, $deref->{attr} );
    }
    return \%info;
}

# Retrieve all the needed information (attribs) from one reference (refname) going from the given node,
# store it as a part of the given hash reference (info). If there is a list of references, store all the values
# separated with spaces.
sub _get_deref_attribs {

    my ( $self, $node, $info, $refname, $attribs ) = @_;
    my $refs = $node->get_deref_attr($refname);    # get the referenced node(s)

    foreach my $attrib ( @{$attribs} ) {

        my $val = '';

        if ( ref($refs) eq 'ARRAY' ) {             # more nodes
            foreach my $refdnode ( @{$refs} ) {
                $val .= $refdnode->get_attr($attrib) . ' ';
            }
            $val = substr $val, 0, length($val) - 1;
        }
        elsif ($refs) {                            # just one node
            $val = $refs->get_attr($attrib);
        }

        # store the value(s) found
        $info->{ $refname . '-' . $attrib } = $val;
    }
    return;
}

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

If a special parameter with the name C<head> is requested, the word ID of the current node's head will be
returned as the value.

=item C<deref_attrib>

A list of attributes of referenced nodes in the form:
   
    reference_1:attr1 attr2, reference_2:attr1 attr2 ..., ...

The returned values are the values of these attributes for referenced nodes, or empty values if there is 
no such reference.

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
