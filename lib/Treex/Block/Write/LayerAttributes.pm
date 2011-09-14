package Treex::Block::Write::LayerAttributes;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Log;
use Treex::PML::Instance;

requires '_process_tree';

has 'layer' => ( isa => enum( [ 'a', 't', 'p', 'n' ] ), is => 'ro', required => 1 );

has 'attributes' => ( isa => 'ArrayRef', is => 'ro', required => 1, builder => '_build_attributes', lazy_build => 1 );

has 'modifier_config' => ( isa => 'HashRef', is => 'ro', builder => '_build_modif_args', lazy_build => 1 );

# A list of output attributes, given all the modifiers are applied
has '_output_attrib' => ( isa => 'ArrayRef', is => 'ro', writer => '_set_output_attrib' );

# Input-output attribute matching (needed for attribute name overrides)
has '_attrib_io' => ( isa => 'HashRef', is => 'ro', writer => '_set_attrib_io' );

# This is where all created text modifier objects are stored
has '_modifiers' => ( isa => 'HashRef', is => 'ro', writer => '_set_modifiers' );

# Parse the attribute list given in parameters.
sub _build_attributes {

    my ($self) = @_;
    my $ret = $self->attributes;
    
    if ( ref $ret eq 'ARRAY' ){
        return $ret;
    }
    return _split_csv_with_brackets( $self->attributes );
}

# Parse the text modifier settings (perl code given in a parameter that must return a hashref)
sub _build_modif_args {

    my ($self) = @_;

    my $ret = _parse_hashref( 'modifier_config', $self->modifier_config );

    foreach my $key ( keys %{$ret} ) {

        if ( $key !~ m/::./ ) {    # prepend default package name
            $ret->{ 'Treex::Block::Write::LayerAttributes::' . $key } = $ret->{$key};
            delete $ret->{$key};
        }
    }
    return $ret;
}

# Parse a hash reference: given a hash reference, do nothing, given a string, try to eval it.
sub _parse_hashref {

    my ( $name, $hashref ) = @_;

    return {} if ( !$hashref );

    if ( ref $hashref ne 'HASH' ) {
        $hashref = eval $hashref || log_fatal('Cannot parse modifier configuration!');

        if ( ref $hashref ne 'HASH' ) {
            log_fatal('Modifier configuration must be a hash reference!');
        }
    }

    return $hashref;
}

# Build the output attributes
sub BUILD {

    my ( $self, $args ) = @_;
    my @output_attr = ();
    my %modifiers   = ();
    my %attr_io     = ();

    foreach my $attr ( @{ $self->attributes } ) {
        if ( my ( $pckg, $func_args ) = _get_function_pckg_args($attr) ) {

            # find the package
            eval "require $pckg" || log_fatal( 'Cannot require package ' . $pckg );

            # create the object (need to supply a dummy empty hash if there are no parameters, an "undef" won't do)
            $modifiers{$pckg} = $pckg->new( defined( $self->modifier_config->{$pckg} ) ? $self->modifier_config->{$pckg} : {} );

            # check if it does our needed role
            log_fatal("The $pckg package doesn't have the Treex::Block::Write::LayerAttributes::AttributeModifier role!")
                if ( !$modifiers{$pckg}->does('Treex::Block::Write::LayerAttributes::AttributeModifier') );

            # get all return values
            $attr_io{$attr} = [ map { $attr . $_ } @{ $modifiers{$pckg}->return_values_names } ];
            push @output_attr, @{ $attr_io{$attr} };
        }
        else {
            $attr_io{$attr} = [ $attr ];
            push @output_attr, $attr;
        }
    }

    $self->_set_modifiers( \%modifiers );   
    $self->_set_attrib_io( \%attr_io );
    $self->_set_output_attrib( \@output_attr );

    return;
}

# Split space-or-comma separated values that may contain brackets with enclosed commas or spaces
sub _split_csv_with_brackets {

    my ($str) = @_;
    $str =~ s/^[\s,]*//;
    $str .= ' ';
    my @arr = ();
    while ( $str =~ m/([a-zA-Z0-9_:-]+\([^\)]*\)+|[^\(\s,]*)[\s,]+/g ) {
        push @arr, $1;
    }

    return \@arr;
}

# the main method
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

sub _get_function_pckg_args {

    my ($attrib) = @_;

    if ( my ( $func, $args ) = $attrib =~ m/^([A-Za-z_0-9:]+)\((.*)\)$/ ) {

        if ( $func !~ m/::./ ) {    # default package: Treex::Block::Write::LayerAttributes
            $func = 'Treex::Block::Write::LayerAttributes::' . $func;
        }
        return ( $func, $args );
    }
    return;
}

sub _get_modified {

    my ( $self, $node, $attrib, $alignment_hash ) = @_;

    if ( my ( $pckg, $args ) = _get_function_pckg_args($attrib) ) {

        # obtain all the arguments
        my @vals = ();
        foreach my $arg ( @{ _split_csv_with_brackets($args) } ) {
            my $curvals = $self->_get_modified( $node, $arg, $alignment_hash );
            push @vals, @{$curvals};
        }

        # call the modifier function on them
        @vals = $self->_modifiers->{$pckg}->modify_all(@vals);

        # harvest the results
        return \@vals;
    }
    else {
        return [ $self->_get_data( $node, $attrib, $alignment_hash ) ];
    }
}

# Return all the required information for a node as a hash
sub _get_info_hash {

    my ( $self, $node, $alignment_hash ) = @_;
    my %info;
    my $out_att_pos = 0;

    foreach my $attrib ( @{ $self->attributes } ) {

        my $vals = $self->_get_modified( $node, $attrib, $alignment_hash );
        foreach my $i ( 0 .. ( @{$vals} - 1 ) ) {
            $info{ $self->_output_attrib->[ $out_att_pos++ ] } = $vals->[$i];
        }
    }
    return \%info;
}

sub _get_data {

    my ( $self, $node, $attrib, $alignment_hash ) = @_;

    my ( $ref, $ref_attr ) = split( /->/, $attrib, 2 );

    # references
    if ($ref_attr) {

        my @nodes = $self->_get_referenced_nodes( $node, $ref, $alignment_hash );

        # call myself recursively on the referenced nodes
        return join( ' ', grep { defined($_) } map { $self->_get_data( $_, $ref_attr, $alignment_hash ) } @nodes );
    }

    # plain attributes
    else {

        # special attribute -- address (calling get_address() )
        if ( $attrib eq 'address' ) {
            return $node->get_address();
        }

        # plain attributes
        else {
            my @values = Treex::PML::Instance::get_all( $node, $attrib );

            return undef if ( @values == 1 and not defined( $values[0] ) );    # leave single undefined values as undefined
            return join( ' ', grep { defined($_) } @values );
        }

    }
}

# Given the source node and the reference name, this retrieves all the referenced nodes
sub _get_referenced_nodes {

    my ( $self, $node, $ref, $alignment_hash ) = @_;

    # special references -- methods: syntactic relations (see POD)
    if ( $ref eq 'parent' ) {
        return ( $node->get_parent() );
    }
    elsif ( $ref eq 'children' ) {
        return $node->get_children( { ordered => 1 } );
    }
    elsif ( $ref eq 'echildren' ) {
        return $node->get_echildren( { or_topological => 1, ordered => 1 } );
    }
    elsif ( $ref eq 'eparents' ) {
        return $node->get_eparents( { or_topological => 1, ordered => 1 } );
    }
    elsif ( $ref eq 'nearest_eparent' ) {
        return _get_nearest( $node, $node->get_eparents( { or_topological => 1, ordered => 1 } ) );
    }
    elsif ( $ref eq 'siblings' ) {
        return $node->get_siblings( { ordered => 1 } );
    }
    elsif ( $ref eq 'lsiblings' ) {
        return $node->get_siblings( { preceding_only => 1 } );
    }
    elsif ( $ref eq 'rsiblings' ) {
        return $node->get_siblings( { following_only => 1 } );
    }
    elsif ( $ref eq 'nearest_lsibling' ) {
        return _get_nearest( $node, $node->get_siblings( { preceding_only => 1 } ) );
    }
    elsif ( $ref eq 'nearest_rsibling' ) {
        return _get_nearest( $node, $node->get_siblings( { following_only => 1 } ) );
    }
    elsif ( $ref =~ m/^(nearest_)?e(l|r|)siblings?$/ ) {    # effective siblings (ef. children of the nearest ef. parent)

        my $eparent = _get_nearest( $node, $node->get_eparents( { or_topological => 1, ordered => 1 } ) );
        my @nodes = $eparent->get_echildren( { ordered => 1 } );

        if ( $ref eq 'esiblings' ) {
            return @nodes;
        }
        elsif ( $ref eq 'elsiblings' ) {
            return grep { $_->ord < $node->ord } @nodes;
        }
        elsif ( $ref eq 'ersiblings' ) {
            return grep { $_->ord > $node->ord } @nodes;
        }
        elsif ( $ref eq 'nearest_elsibling' ) {
            return _get_nearest( $node, grep { $_->ord < $node->ord } @nodes );
        }
        elsif ( $ref eq 'nearest_ersibling' ) {
            return _get_nearest( $node, grep { $_->ord > $node->ord } @nodes );
        }
    }

    # topological neighbors
    elsif ( my ( $dir, $from, $to ) = ( $ref =~ m/^(left|right)([0-9]+)(?:_([0-9]*))?$/ ) ) {

        $to = $from if ( !$to );

        my $from = $dir eq 'left' ? $node->ord - $from : $node->ord + $from;
        my $to   = $dir eq 'left' ? $node->ord - $to   : $node->ord + $to;
        ( $from, $to ) = ( $to, $from ) if ( $dir eq 'left' );

        my @sent = $node->get_root->get_descendants( { ordered => 1 } );
        $from = List::Util::max( $from - 1, 0 );
        $to = List::Util::min( $to - 1, scalar(@sent) - 1 );
        return @sent[ $from .. $to ];
    }

    # alignment relation
    elsif ( $ref eq 'aligned' ) {

        # get alignment from the mapping provided in a hash
        if ($alignment_hash) {
            my $id = $node->id;
            if ( $alignment_hash->{$id} ) {
                return @{ $alignment_hash->{$id} };
            }
        }

        # get alignment from $node->get_aligned_nodes()
        else {
            my ( $aligned_nodes, $aligned_nodes_types ) = $node->get_aligned_nodes();
            if ($aligned_nodes) {
                return @{$aligned_nodes};
            }
        }
    }

    # referencing attributes
    else {

        # find references
        my @values   = Treex::PML::Instance::get_all( $node, $ref );
        my $document = $node->get_document();
        my @nodes    = @values ? map { $document->get_node_by_id($_) } grep {$_} @values : ();

        # sort, if possible
        if ( @nodes > 0 and $nodes[0]->does('Treex::Core::Node::Ordered') ) {
            @nodes = sort { $a->ord <=> $b->ord } @nodes;
        }
        return @nodes;
    }
}

# Given a node and an array of candidate siblings/parents etc., this returns the topologically closest candidate to the node.
sub _get_nearest {

    my ( $node, @nodes ) = @_;

    if ( @nodes > 0 ) {
        my $nearest = $nodes[0];
        foreach my $cand (@nodes) {
            $nearest = $cand if ( abs( $cand->ord - $node->ord ) < abs( $nearest->ord - $node->ord ) );
        }
        return ($nearest);
    }
    return ();
}

# Return all the required information for a node as an array
sub _get_info_list {

    my ( $self, $node, $alignment_hash ) = @_;

    my $info = $self->_get_info_hash( $node, $alignment_hash );
    return [ map { $info->{$_} } @{ $self->_output_attrib } ];
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different layers and different attributes. All blocks with this
role must override the C<_process_tree()> method.

An arbitrary number of attribute references may be dereferenced using a C<-&gt;> character sequence, e.g. 
C<a/aux.rf-&gt;parent-&gt;tag>. 

Several special references are supported in addition to any referencing attribute values within the nodes themselves:

=over

=item C<aligned> means all nodes aligned to this node. 

If alignment info is not stored
in nodes of this tree but in their counterparts, you must provide a backward
node id to aligned nodes mapping (Str to ArrayRef[Node]) as a hash reference,
called C<$alignment_hash> in the code. For an example on how to do that,
see L<Treex::Block::Write::AttributeSentencesAligned>.

=item C<parent>, C<children>: the topological parent / children of the current node. 

=item C<eparents>, C<echildren> looks for all effective parents or children of the current node.

=item C<nearest_eparent> finds the (topologically) nearest effective parent of this node.

=item C<siblings>, C<rsiblings>, C<lsiblings>: all / preceding / following siblings of this node.

=item C<nearest_lsibling>, C<nearest_rsibling> finds the nearest preceding / following sibling of this node. 

=item C<esiblings>, C<ersiblings>, C<elsiblings>: all / preceding / following effective siblings of this node.

An effective sibling is an effective child of the nearest effective parent of this node.

=item C<nearest_elsibling>, C<nearest_ersibling>: nearest preceding / following effective sibling of the node.

=item C<left#>, C<left#-#>, C<right#>, C<right#-#>: the #-th neighbor to the left or right.

If there are two numbers specified, all neighbors within the given range are returned.

=back

All values of multiple-valued attributes are returned, separated with a space.

There is also one special non-reference value, C<address>, which returns the result of the C<get_address> function
call on the current node.

Furthermore, text modifying functions may be applied to the retrieved attribute values, e.g. 
C<CzechCoarseTag(a/aux.rf-&gt;tag)>. Such functions may take more arguments and return more values. Nesting
the modifiing functions is also allowed. 

The text modifying function must be a package that implements the L<Treex::Block::Write::LayerAttributes::AttributeModifier>
role. All packages in the L<Treex::Block::Write::LayerAttributes> directory role are supported implicitly, 
without the need for full package specification; packages in other locations need to have their full package
name included.

If the attributge modifiers allow or require configuration, it may be passed to them via the C<modifier_config>
parameter. 

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-or-comma-separated list of attributes (relating to the tree nodes on the specified layer) to be 
processed, including references and text modifications (see the general description for more information).
 
This parameter is required.

=item C<modifier_config>

This should contain a Perl code which returns a hash reference, where the keys are the names of attribute 
modifier packages and values are their configuration (which may be a string or a nested hash or array
reference). 

Example:

    modifier_config => "{ 'Matching' => [ '^N ^V ^A', 'tlemma tag' ] }"

This returns a configuration setting for the L<Treex::Block::Write::LayerAttributes::Matching> package.

=back

=head1 TODO

=over 

=item * 

Make the separator for multiple-valued attributes configurable.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
