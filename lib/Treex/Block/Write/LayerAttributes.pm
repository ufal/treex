package Treex::Block::Write::LayerAttributes;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Log;
use Treex::PML::Instance;

has 'layer' => (
    isa => enum( [ 'a', 't', 'p', 'n' ] ),
    is => 'ro',
    required => 1
);

has 'attributes' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1
);

# This is a parsed list of attributes, constructed from the attributes parameter.
has '_attrib_list' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    builder    => '_build_attrib_list',
    writer     => '_set_attrib_list',
    lazy_build => 1
);

# Parse the attribute list given in parameters.
sub _build_attrib_list {

    my ($self) = @_;

    return [ split /[\s,]+/, $self->attributes ];
}

sub process_zone {

    my $self = shift;
    my ($zone) = @_;    # pos_validated_list won't work here

    if ( !$zone->has_tree( $self->layer ) ) {
        log_fatal( 'No tree for ' . $self->layer . ' found.' );
    }
    my $tree = $zone->get_tree( $self->layer );

    $self->_process_tree($tree);
    return 1;
}

sub _process_tree {
    log_fatal("Method _process_tree must be overridden for all Blocks with the LayerAttributes role.");
}

# Return all the required information for a node as a hash
sub _get_info_hash {

    my ( $self, $node, $alignment_hash ) = @_;
    my %info;

    foreach my $attrib ( @{ $self->_attrib_list } ) {

        # referenced attributes
        if ( my ( $ref, $name ) = ( $attrib =~ m/^(.*)->(.*)$/ ) ) {

            my @nodes;

            # special references: syntactic relations
            if ( $ref eq 'parent' ) {
                @nodes = ( $node->get_parent() );
            }
            elsif ( $ref eq 'children' ) {
                @nodes = $node->get_children( { ordered => 1 } );
            }
            elsif ($ref eq 'echildren' ){
                @nodes = $node->get_echildren( { or_topological => 1, ordered => 1 } );
            }
            elsif ($ref eq 'eparents' ){
                @nodes = $node->get_eparents( { or_topological => 1, ordered => 1 } );
            }            
            # alignment relation 
            elsif ($ref eq 'aligned' ){ 
                if ($alignment_hash) { 
                    # get alignment from the mapping provided in a hash 
                    my $id = $node->id; 
                    if ($alignment_hash->{$id}) { 
                        @nodes = @{$alignment_hash->{$id}}; 
                    } 
                } else { 
                    # get alignment from Node->get_aligned_nodes() 
                    my ($aligned_nodes, $aligned_nodes_types) = $node->get_aligned_nodes(); 
                    if ($aligned_nodes) { 
                        @nodes = @{$aligned_nodes}; 
                    } 
                } 
                # now @nodes is an array of nodes aligned to $node 
            } 
            # parents of aligned nodes 
            elsif ($ref eq 'aligned_parent' ){ 
                my @aligned_nodes; 
                if ($alignment_hash) { 
                    # get alignment from the mapping provided in a hash 
                    my $id = $node->id; 
                    if ($alignment_hash->{$id}) { 
                        @aligned_nodes = @{$alignment_hash->{$id}}; 
                    } 
                } else { 
                    # get alignment from Node->get_aligned_nodes() 
                    my ($aligned_nodes, $aligned_nodes_types) = $node->get_aligned_nodes(); 
                    if ($aligned_nodes) { 
                        @aligned_nodes = @{$aligned_nodes}; 
                    } 
                } 
                foreach my $aligned_node (@aligned_nodes) { 
                    my $aligned_parent = $aligned_node->get_parent(); 
                    if ($aligned_parent) { 
                        push @nodes, $aligned_parent; 
                    } 
                } 
                # now @nodes is an array of parents of nodes aligned to $node 
            }             
            # referencing values
            else {

                # find references
                my @values = Treex::PML::Instance::get_all( $node, $ref );
                my $document = $node->get_document();
                @nodes = @values ? map { $document->get_node_by_id($_) } grep {$_} @values : ();

                # sort, if possible
                if ( @nodes > 0 and $nodes[0]->does('Treex::Core::Node::Ordered') ) {
                    @nodes = sort { $a->ord <=> $b->ord } @nodes;
                }
            }

            # gather values in referenced nodes
            $info{$attrib} = join( ' ', grep { defined($_) } map { Treex::PML::Instance::get_all( $_, $name ) } @nodes );
        }
        # special attribute -- address (calling get_address() )
        elsif ( $attrib eq 'address' ){
            $info{$attrib} = $node->get_address();
        }
        # plain attributes
        else {
            if ( $attrib eq 'ctag' ) {

                # Czech tag simplified to POS&CASE
                $info{$attrib} = $self->get_coarse_grained_tag( $node->tag );
            }
            else {
                my @values = Treex::PML::Instance::get_all( $node, $attrib );

                next if ( @values == 1 and not defined( $values[0] ) );    # leave single undefined values as undefined
                $info{$attrib} = join( ' ', grep { defined($_) } @values );
            }
        }
    }
    return \%info;
}

# Return all the required information for a node as an array
sub _get_info_list {

    my ( $self, $node, $alignment_hash ) = @_;

    my $info = $self->_get_info_hash( $node, $alignment_hash );
    return [ map { $info->{$_} } @{ $self->_attrib_list } ];
}

# Czech tag simplified to POS&CASE (or POS&SUBPOS if no case)
sub get_coarse_grained_tag {
    my ( $self, $tag ) = @_;

    my $ctag;
    if ( substr( $tag, 4, 1 ) eq '-' ) {

        # no case -> PosSubpos
        $ctag = substr( $tag, 0, 2 );
    }
    else {

        # case -> PosCase
        $ctag = substr( $tag, 0, 1 ) . substr( $tag, 4, 1 );
    }

    return $ctag;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different layers and different attributes. All blocks with this
role must override the C<_process_tree()> method.

One level of attribute references may be dereferenced using a C<-&gt;> character sequence, e.g. C<a/aux.rf-&gt;afun>. Several
special references — C<parent>, C<children>, C<aligned> and C<aligned_parent> - are supported in addition to any references within the nodes themselves.

C<aligned> means all nodes aligned to this node. If alignment info is not stored
in nodes of this tree but in their counterparts, you must provide a backward
node id to aligned nodes mapping (Str to ArrayRef[Node]) as a hash reference,
called C<$alignment_hash> in the code. For an example on how to do that,
see L<Treex::Block::Write::AttributeSentencesAligned>.

C<aligned_parent-&gt;> is a shortcut for C<aligned-&gt;parent-&gt;>
(meant semantically, as C<aligned-&gt;parent-&gt;> itself is not supported).

A special field C<ctag> (coarse grained tag) can be used for Czech, intended
for cases where the full tag is too detailed for you. It has the form of
C<PosCase> (eg. C<N4>) if a morphological case is set, and
C<PosSubpos> (eg. C<VB>) otherwise.
 
All values of multiple-valued attributes are returned, separated with a space.

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-separated list of attributes (relating to the tree nodes on the specified layer) to be processed. 
This parameter is required.

=back

=head1 TODO

Make the separator for multiple-valued attributes configurable.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
