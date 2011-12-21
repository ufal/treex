package Treex::Block::Write::LayerAttributes::TreeDistance;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

# has 'mode' => ( isa => enum( [ 'numeric', '3level', 'binary' ] ), is => 'ro', default => 'numeric' );

# has 'signed' => ( isa => Bool, is => 'ro', default => '1' );

# has 'effective' => ( isa => Bool, is => 'ro', default => '0' );


sub modify_single {

    my ( $self, $ancestor, $descendent ) = @_;
    
    my $distance = 0;

    if (defined $ancestor && defined $descendent) {
        # try standard distance
        $distance = $self->_compute_distance ($ancestor, $descendent);
        if ($distance == 0) {
            # try inversed distance
            $distance = - ($self->_compute_distance ($descendent, $ancestor));
        }
    } else {
        $distance = 0;
    }

    # TODO: apply 'mode' and 'signed' parameters

    return $distance;
}

sub _compute_distance {
    
    my ( $self, $ancestor, $descendent ) = @_;
    
    my $ancestor_id = $ancestor->get_attr('id');
    my $descendent_id = $descendent->get_attr('id');
    
    my $current_node = $descendent;
    my $distance = 0;
    while( 
        !$current_node->is_root()
        && $current_node->get_attr('id') ne $ancestor_id
    ) {
        # TODO: apply 'effective' parameter
	    $current_node = $current_node->get_parent();
	    $distance++;
    }

    if ($current_node->get_attr('id') ne $ancestor_id) {
        # the $ancestor node was not found as an ancestor of $descendent node
        $distance = 0;
    }

    return $distance;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::TreeDistance

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::TreeDistance->new( mode => 'numeric' ); 

    print $modif->modify_all( $ancestor, $descendent );
    # prints the tree distance between the nodes
    
    # or in a treex scenario:
    
    treex \
        Write::AttributeSentencesAligned \
        language=cs alignment_language=en layer=a \
        alignment_type=int.gdfa \
        attributes="ord form lemma CzechCoarseTag(tag) tag parent->ord afun \          
        aligned->ord aligned->tag aligned->afun aligned->parent->ord \                 
        TreeDistance(parent->aligned->node, aligned->node)"

    # in future one will be also able to add something like
        modifier_config="{ TreeDistance => {mode => 'numeric',
            signed => '1', effective => '0'} }"

=head1 DESCRIPTION

A modifier for blocks using L<Treex::Block::Write::LayerAttributes>
which takes two L<Treex::Core::Node> arguments
(supposedly but not necessarily an ancestor and its descendent)
and returns their B<tree distance>. Distance of C<1> means that the
nodes have a parent-child relationship, distance of C<2> means that
the ancestor node is the grandparent of the descendent node, etc.

A value of C<0> means that the distance cannot be determined - either at least
one of the nodes is undefined, or the aligned nodes
are not in ancestor-descendent relationship
(they are eg. brother and sister or uncle and nephew).
(Actually, C<0> would also be returned if C<$ancestor == $descendent>
but I believe there is little reason for using it that way.)

The actual behaviour is influenced by several parameters - see below.

=head1 PARAMETERS

TODO - not implemented yet, hard-set to C<signed=1, mode=numeric, effective=0>.

=over

=item C<signed>

If C<signed> is set to C<1>, a distance lower than 0 means that
the C<$ancestor> node is in fact a descendent of the C<$descendent> node.

If C<signed> is set to C<0>, the absolute value is returned, i.e.
the result is the asme if you switch the nodes.

=item C<effective>

If C<effective> is set to C<1>, effective relations are used instead of
topological ones.

TODO: but there can be multiple effective parents to a node,
so we has to search them all!!

=item C<mode>

The mode this modifier should be working in. The allowed values are:

=over

=item C<numeric>

the actual numeric distance (absolute value)

=item C<3level>

a three-level resolution -- a direct neighbor ('near') / max. 4 nodes away ('close') / farther ('far')

=item C<binary>

just tells if the first node is a direct neighbor of the second one

=back

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
