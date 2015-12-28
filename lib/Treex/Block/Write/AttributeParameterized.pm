package Treex::Block::Write::AttributeParameterized;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Log;
use Readonly;

#
# DATA
#

# The list of attributes (including references etc.) to be processed
subtype 'Treex::Block::Write::AttributeParameterized::AttributesList' => as 'ArrayRef';
coerce 'Treex::Block::Write::AttributeParameterized::AttributesList' =>
    from 'Str' => via { _split_csv_with_brackets($_) };

has 'attributes' => (
    isa      => 'Treex::Block::Write::AttributeParameterized::AttributesList',
    is       => 'ro',
    required => 1,
    coerce   => 1
);

# Configuration for attribute modifiers
subtype 'Treex::Block::Write::AttributeParameterized::ModifierConfig' => as 'HashRef';
coerce 'Treex::Block::Write::AttributeParameterized::ModifierConfig' =>
    from 'Undef' => via { return {} },
    from 'Str' => via { _parse_modifier_config($_) },
    from 'HashRef' => via { _parse_modifier_config($_) };

has 'modifier_config' => (
    isa     => 'Treex::Block::Write::AttributeParameterized::ModifierConfig',
    is      => 'ro',
    coerce  => 1,
    builder => '_return_undef_modifier_config'
);

has instead_undef => ( is => 'ro', isa => 'Str', default => 'undef', documentation => 'What to return instead undefined attributes. Default is "undef" which returns real Perl undef.' );
has instead_empty => ( is => 'ro', isa => 'Str', default => '',      documentation => 'What to return instead of empty (string) attributes. Default is the empty string.' );

# A list of output attributes, given all the modifiers are applied
has '_output_attrib' => ( isa => 'ArrayRef', is => 'ro', writer => '_set_output_attrib' );

# Input-output attribute matching (needed for attribute name overrides)
has '_attrib_io' => ( isa => 'HashRef', is => 'ro', writer => '_set_attrib_io' );

# This is where all created text modifier objects are stored
has '_modifiers' => ( isa => 'HashRef', is => 'ro', writer => '_set_modifiers' );

has '_cache' => ( isa => 'HashRef', is => 'ro', writer => '_set_cache' );

#
# METHODS
#

# A dummy builder for modifier_config to allow it to be overridden in ArffWriting.
sub _return_undef_modifier_config {
    return undef;
}

# Parse the text modifier settings (Perl code given in a parameter that must return a hashref)
sub _parse_modifier_config {

    my ($value) = @_;
    $value = _parse_hashref($value) if ( ref $value ne 'HASH' );

    foreach my $key ( keys %{$value} ) {

        if ( $key !~ m/::./ ) {    # prepend default package name
            $value->{ 'Treex::Block::Write::LayerAttributes::' . $key } = $value->{$key};
            delete $value->{$key};
        }
    }
    return $value;
}

# Parse a hash reference: given a hash reference, do nothing, given a string, try to eval it.
sub _parse_hashref {

    my ($hashref) = @_;

    return {} if ( !$hashref );

    if ( ref $hashref ne 'HASH' ) {
        $hashref = eval $hashref || log_fatal( 'Cannot parse the given hash reference: ' . $hashref );

        if ( ref $hashref ne 'HASH' ) {
            log_fatal( 'The given value must be a hash reference: ' + $hashref );
        }
    }

    return $hashref;
}


# Build the output attributes
before 'BUILD' => sub {

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
            $attr_io{$attr} = [$attr];
            push @output_attr, $attr;
        }
    }

    $self->_set_modifiers( \%modifiers );
    $self->_set_attrib_io( \%attr_io );
    $self->_set_output_attrib( \@output_attr );

    return;
};

# Split space-or-comma separated values that may contain brackets with enclosed commas or spaces
sub _split_csv_with_brackets {

    my ($str) = @_;

    $str =~ s/^[\s,]*//;
    $str .= ' ';
    my @arr   = ();
    my $last  = 0;
    my $depth = 0;
    while ( $str =~ m/([\s,]+|[\(\)])/g ) {
        if ( $1 eq ')' ) {
            $depth--;
            log_fatal('Cannot parse attributes list: too many closing brackets') if ( $depth < 0 );
        }
        elsif ( $1 eq '(' ) {
            $depth++;
        }
        elsif ( $depth == 0 ) {
            push @arr, substr( $str, $last, pos($str) - $last - length($1) );
            $last = pos $str;
        }        
    }
    log_fatal('Cannot parse attributes list: not enough closing brackets') if ($depth > 0);
    return \@arr;
}

# Clearing cache for each processed tree
# Because of this modifier, LayerParameterized must be applied before AttributeParameterized
before 'process_zone' => sub {
    my ($self) = @_;
    $self->_set_cache( {} );
    return;
};

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

    # if a modifier should be called
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

        # just obtain the attribute
        return [ $self->_get_data( $node, $attrib, $alignment_hash ) ];
    }
}

# Return all the required information for a node as a hash
sub _get_info_hash {

    my ( $self, $node, $alignment_hash ) = @_;
    my %info;
    my $out_att_pos = 0;
    my $out_att     = $self->_output_attrib;

    foreach my $attrib ( @{ $self->attributes } ) {

        my $vals = $self->_get_modified( $node, $attrib, $alignment_hash );

        foreach my $i ( 0 .. ( @{$vals} - 1 ) ) {
            my $val = $vals->[$i];
            if ( !defined $val ) {
                $val = $self->instead_undef if $self->instead_undef ne 'undef';
            }
            elsif ( $val eq '' ) {
                $val = $self->instead_empty;
            }
            $info{ $out_att->[ $out_att_pos++ ] } = $val;
        }
    }
    return \%info;
}

sub _get_data {

    my ( $self, $node, $attrib, $alignment_hash ) = @_;

    my ( $ref, $ref_attr ) = split( /->/, $attrib, 2 );

    # references
    if ($ref_attr) {

        my $first_only = ( $ref =~ s/^(.+):first$/$1/ );    # will be 1 if the name ends with 'first'
        my $nodes = $self->_get_referenced_nodes( $node, $ref, $alignment_hash );

        # use only the first referenced node
        if ( $first_only || $ref_attr eq 'node' ) {         # TODO using only first 'node' is not correct
            my $reffed_node = $nodes->[0];
            return $self->_get_data( $reffed_node, $ref_attr, $alignment_hash );
        }

        # call myself recursively on all the referenced nodes
        else {
            return join(
                ' ',
                grep { defined($_) && $_ =~ m/[^\s]/ }
                    map { $self->_get_data( $_, $ref_attr, $alignment_hash ) } @{$nodes}
            );
        }
    }

    # plain attributes
    else {
    
        # wild attributes are prefixed with "wild_"
        if ( $attrib =~ s/^wild_//){
            return $node->wild->{$attrib};
        }

        # special attribute -- address (calling get_address() )
        if ( $attrib eq 'address' ) {
            return $node->get_address();
        }

        # return the actual node (for attribute modifiers)
        elsif ( $attrib eq 'node' ) {
            return $node;
        }
        elsif ( $attrib eq 'alignment_hash' ) {
            return $alignment_hash;
        }

        # plain attributes
        else {
            return $node->get_attr($attrib);
        }
    }
}

# Simple helper methods for _get_referenced_nodes
Readonly my $GET_REF_NODES => {
    'lex_a_node'  => sub { return $_[1]->get_lex_anode() },
    'aux_a_nodes' => sub { return $_[1]->get_aux_anodes( { ordered => 1 } ) },
    't_node_for_lex' => sub { return $_[1]->get_referencing_nodes('a/lex.rf') },
    'a_nodes' => sub { return $_[1]->get_anodes( { ordered => 1 } ) },
    'parent'      => sub { return ( $_[1]->get_parent() ) },
    'src_tnode'   => sub { return ( $_[1]->src_tnode() ) },
    'children'    => sub { return $_[1]->get_children( { ordered => 1 } ) },
    'echildren'   => sub { return $_[1]->get_echildren( { or_topological => 1, ordered => 1 } ) },
    'eparents'    => sub { return $_[1]->get_eparents( { or_topological => 1, ordered => 1 } ) },
    'siblings'  => sub { return $_[1]->get_siblings( { ordered        => 1 } ) },
    'lsiblings' => sub { return $_[1]->get_siblings( { preceding_only => 1 } ) },
    'rsiblings' => sub { return $_[1]->get_siblings( { following_only => 1 } ) },
    'nearest_eparent' => sub { return _get_nearest( $_[1], $_[1]->get_eparents( { or_topological => 1, ordered => 1 } ) ) },
    'nearest_lsibling' => sub { return _get_nearest( $_[1], $_[1]->get_siblings( { preceding_only => 1 } ) ) },
    'nearest_rsibling' => sub { return _get_nearest( $_[1], $_[1]->get_siblings( { following_only => 1 } ) ) },
    'elsiblings'       => sub {
        my ( $self, $node ) = @_;
        return grep { $_->ord < $node->ord } @{ $self->_get_esiblings($node) };
    },
    'ersiblings' => sub {
        my ( $self, $node ) = @_;
        return grep { $_->ord > $node->ord } @{ $self->_get_esiblings($node) };
    },
    'nearest_elsibling' => sub {
        my ( $self, $node ) = @_;
        return _get_nearest( $node, grep { $_->ord < $node->ord } @{ $self->_get_esiblings($node) } );
    },
    'nearest_ersibling' => sub {
        my ( $self, $node ) = @_;
        return _get_nearest( $node, grep { $_->ord > $node->ord } @{ $self->_get_esiblings($node) } );
    },
};

# Given the source node and the reference name, this retrieves all the referenced nodes
sub _get_referenced_nodes {

    my ( $self, $node, $ref, $alignment_hash ) = @_;

    if ( !defined( $self->_cache->{$ref}->{$node} ) ) {

        # any usual neighboring relation (see $GET_REF_NODES for possibilities)
        if ( $GET_REF_NODES->{$ref} ) {
            $self->_cache->{$ref}->{$node} = [ $GET_REF_NODES->{$ref}->( $self, $node ) ];
        }

        # topological neighbors
        elsif ( my ( $dir, $from, $to ) = ( $ref =~ m/^(left|right)([0-9]+)(?:-([0-9]*))?$/ ) ) {

            $self->_cache->{$ref}->{$node} = $self->_get_topol_neighbors( $node, $dir, $from, $to );
        }

        # alignment relation
        elsif ( $ref eq 'aligned' ) {

            # get alignment from the mapping provided in a hash
            if ($alignment_hash) {
                my $id = $node->id;
                if ( $alignment_hash->{$id} ) {
                    $self->_cache->{$ref}->{$node} = $alignment_hash->{$id};
                }
                else {
                    $self->_cache->{$ref}->{$node} = [];
                }
            }

            # get alignment going in both directions 
            else {
                my ( $aligned_nodes, $aligned_nodes_types ) = $node->get_undirected_aligned_nodes();
                if ($aligned_nodes) {
                    $self->_cache->{$ref}->{$node} = $aligned_nodes;
                }
                else {
                    $self->_cache->{$ref}->{$node} = [];
                }
            }
        }

        # unknown relation
        else {
            log_fatal( "Unknown node reference type: " . $ref );
        }
    }

    return $self->_cache->{$ref}->{$node};
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

# Returns the 'effective siblings' of a node (effective children of its effective parent)
sub _get_esiblings {

    my ( $self, $node ) = @_;

    if ( !defined( $self->_cache->{esiblings}->{$node} ) ) {
        if ( !defined( $self->_cache->{nearest_eparent}->{$node} ) ) {
            $self->_cache->{nearest_eparent}->{$node} = [ _get_nearest( $node, $node->get_eparents( { or_topological => 1, ordered => 1 } ) ) ];
        }
        my $eparent = $self->_cache->{nearest_eparent}->{$node}->[0];
        $self->_cache->{esiblings}->{$node} = [ $eparent->get_echildren( { or_topological => 1, ordered => 1 } ) ];
    }
    return $self->_cache->{esiblings}->{$node};
}

sub _get_topol_neighbors {
    my ( $self, $node, $dir, $from, $to ) = @_;

    my $start = $node->ord;
    $to = $from if ( !$to );

    $from = $dir eq 'left' ? $start - $from : $start + $from;
    $to   = $dir eq 'left' ? $start - $to   : $start + $to;
    ( $from, $to ) = ( $to, $from ) if ( $dir eq 'left' );

    if ( !defined( $self->_cache->{sent} ) ) {
        $self->_cache->{sent} = [ $node->get_root->get_descendants( { ordered => 1 } ) ];
    }
    my $sent = $self->_cache->{sent};
    $from = List::Util::max( $from - 1, 0 );
    $to = List::Util::min( $to - 1, scalar( @{$sent} ) - 1 );
    return [ @{$sent}[ $from .. $to ] ];
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

Treex::Block::Write::AttributeParameterized

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different attributes. 

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
the modifying functions is also allowed. 

The text modifying function must be a package that implements the L<Treex::Block::Write::LayerAttributes::AttributeModifier>
role. All packages in the L<Treex::Block::Write::LayerAttributes> directory role are supported implicitly, 
without the need for full package specification; packages in other locations need to have their full package
name included.

If the attribute modifiers allow or require configuration, it may be passed to them via the C<modifier_config>
parameter. 

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-or-comma-separated list of attributes (relating to the tree nodes on the specified layer) to be 
processed, including references and text modifications (see the general description for more information).
Wild attributes are prefixed with "wild_".
 
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

=head1 SEE ALSO

=over 

=item L<Treex::Block::Write::LayerParameterized>

It is possible to combine this role with the C<LayerParameterized> role to 
support also the work with different layers of annotation; please note that the C<with>
clause for this role must go AFTER the C<with> clause of the C<LayerParameterized> 
role. 

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
