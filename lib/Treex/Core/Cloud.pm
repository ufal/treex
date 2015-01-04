package Treex::Core::Cloud;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Coordination;



# type = node: simple wrapper around a Node object
# type = coordination: wrapper around a Coordination object
# type = cloud: group of clouds of arbitrary types
has type =>
(
    is       => 'rw',
    isa      => 'Str',
    writer   => '_set_type',
    reader   => 'type'
);

has node =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Node',
    writer   => '_set_node',
    reader   => '_get_node'
);

has coordination =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Coordination',
    writer   => '_set_coordination',
    reader   => '_get_coordination'
);

# Shared modifiers are clouds that depend on the whole cloud, not just one of its participants.
has _smod =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Cloud]',
    reader   => '_get_smod',
    default  => sub { [] }
);

has parent =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Cloud',
    writer   => '_set_parent',
    reader   => 'parent'
);



#------------------------------------------------------------------------------
# Wraps a Node object in this Cloud object, i.e. creates a node-type cloud.
#------------------------------------------------------------------------------
sub create_from_node
{
    my $self = shift;
    my $node = shift;
    log_fatal('Undefined node.') if(!defined($node) || ref($node) ne 'Treex::Core::Node::A');
    # If the node is delimiter of Coordination and we already know it,
    # i.e. we have been called through create_from_coordination(),
    # then we do not mind whether its afun is Coord
    # and we need the list of its private modifiers because we cannot process all its children.
    # If it is conjunct then we check the afun normally, as it could be a nested Coordination.
    my $coordination_delimiter = shift;
    my $private_modifiers = shift;
    if($coordination_delimiter)
    {
        $self->_set_type('node');
        $self->_set_node($node);
        # Wrap all children as clouds.
        my $smod = $self->_get_smod();
        foreach my $child (@{$private_modifiers})
        {
            my $ccloud = Treex::Core::Cloud->new;
            $ccloud->create_from_node($child);
            $ccloud->_set_parent($self);
            push(@{$smod}, $ccloud);
        }
    }
    else
    {
        my $afun = $node->afun();
        $afun = '' if(!defined($afun));
        if($afun eq 'Coord')
        {
            my $coordination = Treex::Core::Coordination->new;
            $coordination->detect_prague($node);
            $self->create_from_coordination($coordination);
        }
        else
        {
            $self->_set_type('node');
            $self->_set_node($node);
            # Wrap all children as clouds.
            my $smod = $self->_get_smod();
            foreach my $child ($node->children())
            {
                my $ccloud = Treex::Core::Cloud->new;
                $ccloud->create_from_node($child);
                $ccloud->_set_parent($self);
                push(@{$smod}, $ccloud);
            }
        }
    }
    return;
}



#------------------------------------------------------------------------------
# Wraps a Coordination object in this Cloud object, i.e. creates a
# coordination-type cloud.
#------------------------------------------------------------------------------
sub create_from_coordination
{
    my $self = shift;
    my $coordination = shift;
    $self->_set_type('coordination');
    $self->_set_coordination($coordination);
    # Wrap all shared modifiers as clouds.
    my $smod = $self->_get_smod();
    foreach my $modifier ($coordination->get_shared_modifiers())
    {
        my $ccloud = Treex::Core::Cloud->new;
        $ccloud->create_from_node($modifier);
        $ccloud->_set_parent($self);
        push(@{$smod}, $ccloud);
    }
    # Wrap all participants as clouds.
    # We do not need the conjunct-delimiter distinction but we do not want to lose it.
    # We could copy all the information from the Coordination object and store it in a parallel array.
    # That would mean a lot of copying back and forth and we would have to change it each time the implementation of Coordination changes.
    # It will be better in future if the concept of Cloud proves viable and we make the Coordination class a derivative of Cloud.
    # For the moment however, we just abuse the list of records about participants within Coordination, and store the link to the sub-Cloud there.
    my $participants = $coordination->_get_participants();
    foreach my $participant (@{$participants})
    {
        my $node = $participant->{node};
        my $ccloud = Treex::Core::Cloud->new;
        if($participant->{type} eq 'delimiter')
        {
            $ccloud->create_from_node($node, 1, $participant->{pmod});
        }
        else
        {
            $ccloud->create_from_node($node);
        }
        $participant->{cloud} = $ccloud;
    }
    return;
}



#------------------------------------------------------------------------------
# Disconnects a cloud from its parent cloud. Discards the link from child to
# parent and removes the link to the child from the list of modifiers kept
# with the parent. We must do this manually to prevent memory leaks. Perl
# garbage collection will not work because of cyclic references.
#------------------------------------------------------------------------------
sub disconnect_from_parent
{
    my $self = shift;
    my $parent = $self->parent();
    if(defined($parent))
    {
        # Moose will not allow _set_parent(undef) because undef is not of class Treex::Core::Cloud.
        # We will create a dummy object instead. Parent will have the only reference to it and Perl will be able to discard it.
        # I am sure that there must be a better way to do this but I don't know how.
        $self->_set_parent(Treex::Core::Cloud->new);
        my $opsmod = $parent->_get_smod();
        my $found = 0;
        for(my $i = 0; $i<=$#{$opsmod}; $i++)
        {
            if($opsmod->[$i]==$self)
            {
                splice(@{$opsmod}, $i, 1);
                $found = 1;
                last;
            }
        }
        if(!$found)
        {
            log_fatal('Parent cloud does not know me as its shared modifier.');
        }
    }
}



#------------------------------------------------------------------------------
# Manual cleanup top-down: destroy my descendants. Disconnect them from me
# manually (Perl garbage collector would not work with cyclic references).
# (DZ: I tried to monitor memory usage with and without this cleanup and I did
# not observe any difference. But I am leaving it here, just in case.)
#------------------------------------------------------------------------------
sub destroy_children
{
    my $self = shift;
    my $smod = $self->_get_smod();
    foreach my $child (@{$smod})
    {
        $child->destroy_children();
        $child->_set_parent(Treex::Core::Cloud->new); # disconnect from me
    }
    splice(@{$smod});
    if($self->type() eq 'coordination')
    {
        my $participants = $self->_get_coordination()->_get_participants();
        foreach my $participant (@{$participants})
        {
            $participant->{cloud}->destroy_children();
            delete($participant->{cloud});
        }
    }
    return;
}



#------------------------------------------------------------------------------
# Sets the parent cloud of this cloud. Makes sure to also appropriately
# reattach the corresponding nodes. This node will become a shared modifier
# (not participant) of the parent cloud.
#------------------------------------------------------------------------------
sub set_parent
{
    my $self = shift;
    my $pcloud = shift;
    log_fatal('Unknown new parent.') if(!defined($pcloud));
    my $type = $self->type();
    my $ptype = $pcloud->type();
    my $node;
    if($type eq 'node')
    {
        $node = $self->_get_node();
    }
    elsif($type eq 'coordination')
    {
        $node = $self->_get_coordination()->shape_prague();
    }
    my $opcloud = $self->parent();
    # Cleanup: remove me from the list of modifiers of the old parent.
    if(defined($opcloud))
    {
        # If it is a coordination we must do the same with the list of shared modifer nodes in the Coordination.
        if($opcloud->type() eq 'coordination')
        {
            my $opcsmod = $opcloud->_get_coordination()->_get_smod();
            my $found = 0;
            for(my $i = 0; $i<=$#{$opcsmod}; $i++)
            {
                if($opcsmod->[$i]==$node)
                {
                    splice(@{$opcsmod}, $i, 1);
                    $found = 1;
                    last;
                }
            }
            if(!$found)
            {
                log_fatal('Parent coordination does not know me as its shared modifier.');
            }
        }
        $self->disconnect_from_parent();
    }
    $self->_set_parent($pcloud);
    # Reattach the corresponding nodes.
    if($type eq 'node' && $ptype eq 'node')
    {
        $node->set_parent($pcloud->_get_node());
    }
    elsif($type eq 'node' && $ptype eq 'coordination')
    {
        my $pcoordination = $pcloud->_get_coordination();
        $pcoordination->add_shared_modifier($node);
        $pcoordination->shape_prague();
    }
    elsif($type eq 'coordination' && $ptype eq 'coordination')
    {
        my $pcoordination = $pcloud->_get_coordination();
        $pcoordination->add_shared_modifier($node);
        $pcoordination->shape_prague();
    }
    elsif($type eq 'coordination' && $ptype eq 'node')
    {
        my $coordination = $self->_get_coordination();
        $coordination->set_parent($pcloud->_get_node());
        $coordination->shape_prague();
    }
    return;
}



#------------------------------------------------------------------------------
# Returns non-zero if this cloud is coordination.
#------------------------------------------------------------------------------
sub is_coordination
{
    my $self = shift;
    return $self->type() eq 'coordination';
}



#------------------------------------------------------------------------------
# Sets the afun of the cloud. It describes its relation to the parent cloud.
#------------------------------------------------------------------------------
sub set_afun
{
    my $self = shift;
    my $afun = shift;
    if($self->type() eq 'node')
    {
        $self->_get_node()->set_afun($afun);
    }
    elsif($self->type() eq 'coordination')
    {
        my $coordination = $self->_get_coordination();
        $coordination->set_afun($afun);
        $coordination->shape_prague();
    }
    return;
}



#------------------------------------------------------------------------------
# Returns the afun of the cloud. It describes its relation to the parent cloud.
#------------------------------------------------------------------------------
sub afun
{
    my $self = shift;
    if($self->type() eq 'node')
    {
        return $self->_get_node()->afun();
    }
    elsif($self->type() eq 'coordination')
    {
        return $self->_get_coordination()->afun();
    }
}



#------------------------------------------------------------------------------
# Returns the list of clouds that function as shared modifiers of this cloud.
#------------------------------------------------------------------------------
sub get_shared_modifiers
{
    my $self = shift;
    my $smod = $self->_get_smod();
    my @list = @{$smod};
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of clouds that are participants of this cloud. This function
# is used for recursion and it does not return anything for single-node clouds.
#------------------------------------------------------------------------------
sub get_participants
{
    my $self = shift;
    my @list;
    if($self->type() eq 'coordination')
    {
        my $coordination = $self->_get_coordination();
        my $participants = $coordination->_get_participants();
        foreach my $participant (@{$participants})
        {
            push(@list, $participant->{cloud});
        }
    }
    return @list;
}



#------------------------------------------------------------------------------
# Returns the list of all participants and shared modifiers (clouds). This is
# useful for recursion, if we want to traverse all clouds in the tree.
#------------------------------------------------------------------------------
sub get_participants_and_modifiers
{
    my $self = shift;
    my @list = $self->get_shared_modifiers();
    push(@list, $self->get_participants());
    return @list;
}



#------------------------------------------------------------------------------
# Selects a node inside the cloud as the representative of the cloud and
# returns its address.
#------------------------------------------------------------------------------
sub get_address
{
    my $self = shift;
    if($self->type() eq 'node')
    {
        return $self->_get_node()->get_address();
    }
    # It is not clear which node should represent a non-trivial cloud.
    # Remember, we want a cloud to be independent of the current dependency representation of intra-cloud relations.
    # We pick the first participant at the moment.
    else
    {
        my @participants = $self->get_participants();
        if(scalar(@participants)>0)
        {
            return $participants[0]->get_address();
        }
        else
        {
            log_fatal("Cannot identify a node in the cloud to get address of");
        }
    }
}



1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Cloud

=head1 DESCRIPTION

Cloud is a group of nodes. It can be also thought of as a group of subtrees headed by the nodes.
There is a relation between the nodes but we are not sure (or do not yet want to explicitly mark)
what direction the dependencies should go. An example is a preposition and its noun phrase:
one annotation scheme requires that the noun phrase depends on the preposition, another scheme
wants the preposition to depend on the noun phrase.

The nodes (subtrees) that are members of the cloud are called I<participants>. Before they entered
the cloud one of them was probably the head and the others were its dependents. We may need these
dependencies in order to detect and construct a Cloud object but then they are not important for
the cloud. Before the cloud is destroyed, it will select one of the participants the head and make
the others depend on it, based on user preferences. Cloud is a temporary internal structure that
will not be saved in the Treex format on the disk.

Cloud can behave as a generalized Node. It has a parent, an afun (i.e. label of its relation to its
parent), and the is_member attribute (i.e. it can be a conjunct). Besides the children of the
individual participants, hidden in their subtrees, there can be also I<shared modifiers>: nodes
(subtrees) depending on the whole cloud. When we are finished with the cloud, these subtrees will
be attached to whatever node we select as the head of the cloud.

Technically all referenced nodes (participants, parent and shared modifiers) are objects of the
class Cloud, not Node. Undirected dependencies can just be handled recursively and they will interact
correctly (for instance, a chain of AuxP-AuxC-something). Any Node can be trivially converted to
a Cloud with a single participant.

The concept of cloud adds a new dimension of relations to the node network we keep in Treex.
The first dimension is the linear ordering of nodes according to the word order.
The second dimension contains the parent-child relations between nodes or clouds.
The third dimension connects subtrees (or clouds) that are participants of the same cloud.

Cloud should be useful for transformations between different annotation styles, especially in cases
where multiple clouds with different rules interact.

We may want in future to make the Coordination class a special (and most complex) case of Cloud.
Philosophically, coordination is a cloud. Technically however, our current implementation of
the Coordination class operates on Nodes, not Clouds. Therefore if a Node involved in Coordination
is also part of a Cloud and the head preference within the Cloud changes, the Coordination will be
no longer valid (see also discussion in the documentation of Coordination). Similarly the current
implementation of Cloud must carefully check (using Coord afun and is_member attribute) whether
the Nodes it deals with are involved in coordination.

The implementation must also make sure that code that does not know about clouds will still see
a valid tree. It may be achieved by adding new temporary Node objects:

=over

=item There are two temporary artificial nodes: the I<head node> and the I<cloud node>.

=item An artificial node with afun C<Cloud> will serve as the temporary parent of all participants.
They keep their original afuns. We may need the afuns when we reorganize the relations between
participants.

=item Another artificial node will be the parent of the C<Cloud> node and of any shared modifiers.
This node will be attached to the parent node of the cloud, with the afun that reflects the relation
between the cloud and its parent.

=item If the parent of the cloud is a participant of another cloud, our head node's parent is directly
the participant node. If the parent is the other cloud as a whole (we are a shared modifier), our
head node's parent is the head node of the parent cloud.

=item Single nodes that do not participate in any explicitly defined cloud can be viewed as clouds
with head and cloud nodes collapsed into one. No artificial nodes will be generated for them.
There is no need to distinguish between shared and private modifiers.

=back

=head1 METHODS

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
