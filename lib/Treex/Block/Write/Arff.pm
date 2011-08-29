package Treex::Block::Write::Arff;

use Moose;
use Treex::Core::Common;
use Treex::Tool::IO::Arff;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';
with 'Treex::Block::Write::LayerAttributes';

#
# DATA
#

has '+language' => ( required => 1 );

# ARFF data file structure as it's set in Treex::Tool::IO::Arff
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

# Override the default data type settings (format: "columnname: type, ...")
has 'force_types' => ( is => 'ro', isa => 'Str', default => '' );

# The data type override settings, in a hashref
has '_forced_types' => ( is => 'ro', isa => 'HashRef', builder => '_build_forced_types', lazy_build => 1 );

#
# METHODS
#

# De-alias the 'head' parameter
sub BUILDARGS {

    my ( $class, $params ) = @_;

    $params->{attributes} =~ s/(^| )head($| )/$1parent->ord$2/;
    return $params;
}

# Build a hashref from datatype override settings
sub _build_forced_types {

    my ($self) = @_;
    my %forced_types = map { $_ =~ m/\s*(.*)\s*:\s*(.*)\s*/; $1 => $2 } split( /\s*,\s*/, $self->force_types );

    return {%forced_types};
}

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

        if ( defined( $info->{'parent->ord'} ) ) {    # 'head' aliasing
            $info->{'head'} = $info->{'parent->ord'};
            delete $info->{'parent->ord'};
        }

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

    foreach my $attr ( @{ $self->_output_attrib } ) {

        my $attr_entry = {
            attribute_name => ( $attr eq 'parent->ord' ? 'head' : $attr ),
            attribute_type => $self->_forced_types->{$attr}
        };

        push @{ $arff->relation->{attributes} }, $attr_entry;
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

For multiple-valued attributes (lists) and dereferencing attributes, please see L<Treex::Block::Write::LayerAttributes>. 

A special attribute C<head> is an alias for dereferenced attribute C<parent-&gt;ord>.

=item C<force_types>

Override default data type (which is 'NUMERIC', if only numeric values are used, and 'STRING' otherwise). Should
be a comma separated list of C<attribute-name: data-type>.  

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
