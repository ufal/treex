package Treex::Block::Write::AttributeSentencesAligned;

use Moose;
use Treex::Core::Common;
use autodie;

extends 'Treex::Block::Write::BaseTextWriter';

with 'Treex::Block::Write::LayerParameterized';
with 'Treex::Block::Write::AttributeParameterized';

has '+language' => ( required => 1 );

has 'alignment_language' => ( isa => 'Str', is => 'ro', required => 1 );

has 'alignment_selector' => ( isa => 'Str', is => 'ro', default => '' );

has 'alignment_type' => ( isa => 'Str', is => 'ro', required => 1 );

has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => "1" );

has 'separator' => ( isa => 'Str', is => 'ro', default => "\n" );

has 'attribute_separator' => ( isa => 'Str', is => 'ro', default => "\t" );

has 'sentence_separator' => ( isa => 'Str', is => 'ro', default => "\n\n" );

sub _process_tree() {

    my ( $self, $tree ) = @_;

    my @nodes = $tree->get_descendants( { ordered => 1 } );

    # get alignment mapping
    my $alignment_hash = undef;
    if ( $self->alignment_is_backwards ) {

        # we need to provide the other direction of the relation
        $alignment_hash = {};
        my $aligned_root = $tree->get_bundle->get_tree( $self->alignment_language, $self->layer, $self->alignment_selector );
        foreach my $aligned_node ( $aligned_root->get_descendants ) {
            my ( $nodes, $types ) = $aligned_node->get_directed_aligned_nodes();
	    if ($nodes) {
		for (my $i = 0; $i < @{$nodes}; $i++) {
		    my $node = $nodes->[$i];
		    my $type = $types->[$i];
		    my $id = $node->id;
		    if ($self->alignment_type eq $type) {
			if ( $alignment_hash->{$id} ) {
                push @{ $alignment_hash->{$id} }, $aligned_node;
			}
			else {
			    $alignment_hash->{$id} = [$aligned_node];
			}
		    }
		}
	    }
        }
    }

    # else: Node->get_directed_aligned_nodes() will be used directly

    # nodes of a sentence, each node consisting of several attributes
    print { $self->_file_handle } join $self->separator,
        map {
        join $self->attribute_separator,
            @{ $self->_get_info_list( $_, $alignment_hash ) }
        } @nodes;

    print { $self->_file_handle } $self->sentence_separator;
}

# Return all the required information for a node as a hash
sub _get_info_hash {

    my ( $self, $node, $alignment_hash ) = @_;
    my %info;
    my $out_att_pos = 0;
    my $out_att = $self->_output_attrib;

    foreach my $attrib ( @{ $self->attributes } ) {

        my $vals = $self->_get_modified( $node, $attrib, $alignment_hash );

        foreach my $i ( 0 .. ( @{$vals} - 1 ) ) {
            my $value = $vals->[$i];
            if (!defined $value) {
                $value = '';
            }
            $info{ $out_att->[ $out_att_pos++ ] } = $value;
        }
    }
    return \%info;
}



1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::AttributeSentencesAligned

=head1 DESCRIPTION

This prints the values of the selected attributes for all nodes in a tree,
by default in CoNLL-like format (one node per line, its attributes separated
by tabulators, sentences separated by an empty line), although all the
separators can be configured differently.

This writer is based on L<Treex::Block::Write::AttributeSentences>
and is basically very similar.
The main distinction is that this writer also provides
access to attributes of nodes aligned to the nodes being processed.

For multiple-valued attributes (lists) and dereferencing attributes, please 
see L<Treex::Block::Write::AttributeParameterized>. 

=head1 ATTRIBUTES

=over

=item C<language>

The primary language. This parameter is required.

=item C<alignment_language>

The secondary language, which nodes are accesible through
the C<aligned-&gt;> prefix. This parameter is required.

=item C<alignment_selector>

The selector of the zone of C<alignment_language>. Empty by default.

=item C<alignment_is_backwards>

Default value of 1 means that the alignment information is stored in the nodes
of C<alignment_language> and a reverse mapping is to be computed.
Value of 0 means that alignment info is stored in the nodes of C<language>
and nothing has to be precomputed:
L<Treex::Core::Node/get_directed_aligned_nodes> can be used directly.

=item C<attributes>

The name of the attributes whose values should be printed for the individual nodes. This parameter is required.
You can use several special prefixes: C<parent-&gt;> to get acces to attributes
of the parent node, C<children-&gt;> for attributes of all children
(conjoined by a space) and C<aligned-&gt;> for attributes on nodes
aligned to the node (again, all of them).

If there is no value (eg. the node has no children), the value is an empty
string (thus resulting in two C<attribute_separator>s next to each other).
(TODO: let the value returned in this case be configurable.)

=item C<layer>

The annotation layer where the desired attribute is found (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<separator>

The separator character for the individual nodes within one sentence. Newline is the default.

=item C<attribute_separator>

The separator character for the individual attribute values for one node. Tabulator is the default.

=item C<sentence_separator>

The separator string for the individual sentences. Empty line (C<"\n\n">)
is the default.

=item C<to>

Optional: the name of the output file, STDOUT by default.

=item C<encoding>

Optional: the output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
