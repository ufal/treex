package Treex::Core::Cloud;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;



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
