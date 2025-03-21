package Treex::Core::EntitySet;

use utf8;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Entity;



has 'entities' => (is => 'rw', isa => 'ArrayRef', default => sub {[]}, documentation => 'Array holding references to Entity objects, i.e., all entities in the set (document).');
has 'mentions' => (is => 'rw', isa => 'HashRef', default => sub {{}}, documentation => 'Hash holding references to EntityMention objects, i.e., all mentions of all entities in the set (document), indexed by the id of the thead node.');
has 'bridging' => (is => 'rw', isa => 'ArrayRef', default => sub {[]}, documentation => 'Array holding bridging relations. Implemented as typed directed mention-mention relations, but understood as entity-entity relations. Therefore, at most one such relation between a particular pair of entities is allowed.');
has 'last_entity_id' => (is => 'rw', default => 0);



#------------------------------------------------------------------------------
# Takes a t-node and checks whether there is already an entity mention headed
# by this node. If there is, the function returns the EntityMention object.
# Otherwise it returns undef.
#------------------------------------------------------------------------------
sub get_mention_by_thead
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $thead = shift; # Treex::Core::Node::T
    my $id = $thead->id();
    return exists($self->{mentions}{$id}) ? $self->{mentions}{$id} : undef;
}



#------------------------------------------------------------------------------
# Creates an EntityMention object from a t-node, which will be the head of the
# mention. Also creates a new Entity object for this mention. Initially, the
# mention will be a singleton. This function does not yet examine coreference
# links of the t-node. If we later do it, the mention's entity may be merged
# with entities of other mentions.
#------------------------------------------------------------------------------
sub create_mention
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $thead = shift; # Treex::Core::Node::T
    log_fatal('Undefined mention head') if(!defined($thead));
    # Check that there is no mention with this head yet.
    log_fatal('Trying to create mention headed by node that already has another mention') if($self->get_mention_by_thead($thead));
    # If not, create it.
    my $entity = new Treex::Core::Entity('eset' => $self, 'id' => $self->get_new_entity_id($thead));
    push(@{$self->{entities}}, $entity);
    my $mention = $entity->create_mention($thead);
    $self->{mentions}{$thead->id()} = $mention;
    return $mention;
}



#------------------------------------------------------------------------------
# Returns the next available entity id for the current document.
#------------------------------------------------------------------------------
sub get_new_entity_id
{
    my $self = shift;
    my $node = shift; # we need a node to be able to access the bundle
    # We need a new entity id.
    # In released data, the id should be just 'e' + natural number.
    # However, larger unique strings are allowed during intermediate stages,
    # and we need them in order to ensure uniqueness across multiple documents
    # in one file. Entities never span multiple documents, so we will insert
    # the document id. Since Treex documents do not have an id attribute, we
    # will assume that a prefix of the bundle id uniquely identifies the document.
    my $docid = $node->get_bundle()->id();
    # In PDT, remove trailing '-p1s1' (paragraph and sentence number).
    # In PCEDT, remove trailing '-s1' (there are no paragraph boundaries).
    $docid =~ s/-(p[0-9A-Z]+)?s[0-9A-Z]+$//;
    # Certain characters cannot be used in cluster ids because they are used
    # as delimiters in the coreference annotation.
    $docid =~ s/[-|=:,+\s]//g;
    my $last_entity_id = $self->last_entity_id();
    $last_entity_id++;
    $self->set_last_entity_id($last_entity_id);
    my $id = $docid.'e'.$last_entity_id;
    return $id;
}



#------------------------------------------------------------------------------
# Compares two entity ids. It is useful when sorting bridging relations by
# target entities. This function does not need access to an EntitySet object;
# it can be considered static.
#------------------------------------------------------------------------------
sub cmp_entity_ids
{
    my $a = shift;
    my $b = shift;
    my $aid = 0;
    my $bid = 0;
    my $adoc = '';
    my $bdoc = '';
    if($a =~ m/^(.+)e(\d+)$/)
    {
        $adoc = $1;
        $aid = $2;
    }
    if($b =~ m/^(.+)e(\d+)$/)
    {
        $bdoc = $1;
        $bid = $2;
    }
    if($adoc && $bdoc && $aid && $bid)
    {
        my $r = $adoc cmp $bdoc;
        unless($r)
        {
            $r = $aid <=> $bid;
        }
        return $r;
    }
    else
    {
        return $a cmp $b;
    }
}



#------------------------------------------------------------------------------
# If a t-node already has a mention, returns the mention. Otherwise creates the
# mention and then returns it.
#------------------------------------------------------------------------------
sub get_or_create_mention_for_thead
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $thead = shift; # Treex::Core::Node::T
    log_fatal('Undefined mention head') if(!defined($thead));
    my $mention = $self->get_mention_by_thead($thead);
    if(!defined($mention))
    {
        $mention = $self->create_mention($thead);
    }
    return $mention;
}



#------------------------------------------------------------------------------
# Returns the list of all mentions within a given bundle (sentence).
#------------------------------------------------------------------------------
sub get_mentions_in_bundle
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $bundle = shift;
    return map {$self->{mentions}{$_}} (grep {$self->{mentions}{$_}->thead()->get_bundle() == $bundle} (sort(keys(%{$self->{mentions}}))));
}



#------------------------------------------------------------------------------
# Removes a mention from the set. This may result in removing an entity, if it
# was a singleton. Bridging relations starting or ending at the mention will be
# removed, too (they will not be moved to another mention of the same entity).
# The t-node that serves as the head of the mention will stay untouched in the
# tree.
#------------------------------------------------------------------------------
sub remove_mention
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $mention = shift;
    log_fatal('Cannot remove undefined mention') if(!defined($mention));
    # Update bridging relations.
    my @bridging = grep {$_->{srcm} != $mention && $_->{tgtm} != $mention} (@{$self->bridging()});
    $self->set_bridging(\@bridging);
    # Remove the mention from its entity.
    my $entity = $mention->entity();
    $mention->set_entity(undef);
    delete($entity->mentions()->{$mention->thead()});
    # Remove the entity if this was its only mention.
    my $n = scalar(keys(%{$entity->mentions()}));
    if($n == 0)
    {
        my @entities = grep {$_ != $entity} (@{$self->entities()});
        $self->set_entities(\@entities);
    }
    # Remove the mention from the eset-wide hash.
    delete($self->mentions()->{$mention->thead()});
}



#------------------------------------------------------------------------------
# Merges two entities into one. This must be done when a coreference link is
# discovered between two mentions that have so far been in different entities.
#------------------------------------------------------------------------------
sub merge_entities
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 3);
    my $self = shift;
    my $e1 = shift; # Entity object that will be kept
    my $e2 = shift; # Entity object that will be swallowed
    log_fatal('Undefined first entity') if(!defined($e1));
    log_fatal('Undefined second entity') if(!defined($e2));
    # Double check that these entities belong to the present set.
    log_fatal('Unknown first entity') if(!any {$_ == $e1} (@{$self->entities()}));
    log_fatal('Unknown second entity') if(!any {$_ == $e2} (@{$self->entities()}));
    # Use the lower id. The higher id will remain unused.
    my $id1 = $e1->id();
    my $id2 = $e2->id();
    $id1 =~ s/^(.*)e(\d+)$/$2/;
    $id2 =~ s/^(.*)e(\d+)$/$2/;
    my $merged_id = $1.'e'.($id1 < $id2 ? $id1 : $id2);
    $e1->set_id($merged_id);
    # If e1 does not have type and e2 does, copy it.
    $e1->reconsider_type($e2->type());
    # Verify that there is no bridging relation between the two entities.
    # If there is one, it must be removed.
    my @new_bridging;
    foreach my $b (@{$self->bridging()})
    {
        my $bsrce = $b->{srcm}->entity();
        my $btgte = $b->{tgtm}->entity();
        my $btype = $b->{type};
        if($bsrce == $e1 && $btgte == $e2 || $bsrce == $e2 && $btgte == $e1)
        {
            log_warn("Removing bridging relation '$btype' because its source and target entities are being merged.");
        }
        else
        {
            push(@new_bridging, $b);
        }
    }
    $self->set_bridging(\@new_bridging);
    # Move the mentions from $e2 to $e1.
    my @e2mentionids = sort(keys(%{$e2->mentions()}));
    foreach my $mid (@e2mentionids)
    {
        # No mention can be in multiple entities, so $e1 must not have it from before.
        log_fatal('Mention already in target entity') if(exists($e1->mentions()->{$mid}));
        my $m = $e2->mentions()->{$mid};
        $m->set_entity($e1);
        $e1->mentions()->{$mid} = $m;
        delete($e2->mentions()->{$mid});
    }
    # Destroy $e2.
    $e2->set_eset(undef);
    my @entities = grep {$_ != $e2} (@{$self->entities()});
    $self->set_entities(\@entities);
    return $e1;
}



#------------------------------------------------------------------------------
# Adds a bridging relation to the list. Takes the source mention, the target
# mention, and relation type as parameters. Despite being drawn between
# mentions, the relations are understood as relations between entities, and at
# most one such relation is allowed between any pair of entities.
#------------------------------------------------------------------------------
sub add_bridging
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 4);
    my $self = shift;
    my $srcm = shift; # source mention
    my $tgtm = shift; # target mention
    my $type = shift; # bridging relation type
    my $srce = $srcm->entity();
    my $tgte = $tgtm->entity();
    # Verify that there is no bridging relation between the two entities yet.
    foreach my $b (@{$self->bridging()})
    {
        my $bsrce = $b->{srcm}->entity();
        my $btgte = $b->{tgtm}->entity();
        my $btype = $b->{type};
        if($bsrce == $srce && $btgte == $tgte)
        {
            log_warn("Ignoring bridging relation '$type' because a '$btype' relation already exists between the same entities.");
            return;
        }
        elsif($bsrce == $tgte && $btgte == $srce)
        {
            log_warn("Ignoring bridging relation '$type' because a reversed '$btype' relation already exists between the same entities.");
            return;
        }
    }
    push(@{$self->bridging()}, {'srcm' => $srcm, 'tgtm' => $tgtm, 'type' => $type});
}



#------------------------------------------------------------------------------
# Gets all bridging relations starting at a mention. We need them when we are
# saving mention information as MISC attributes of its head a-node.
#------------------------------------------------------------------------------
sub get_bridging_starting_at_mention
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $mention = shift;
    my @bridging = sort {cmp_entity_ids($a->{tgtm}->entity()->id(), $b->{tgtm}->entity()->id())} (grep {$_->{srcm} == $mention} (@{$self->bridging()}));
    return @bridging;
}



#------------------------------------------------------------------------------
# Returns a textual representation of the phrase and all subphrases. Useful for
# debugging. This is an abstract method that must be implemented in the derived
# classes.
#------------------------------------------------------------------------------
sub as_string
{
    my $self = shift;
    log_fatal("The as_string() method is not implemented");
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::EntitySet

=head1 DESCRIPTION

This object holds references to all entities and all entity mentions in one
document. The entities and mentions have back references to their entity set
so that they can query other existing entities and mentions.

=head1 ATTRIBUTES

=over

=item entities

A list of C<Entity> objects.

=item mentions

A hash of C<EntityMention> objects, indexed by the id of the thead node.

=item bridging

A list of bridging relations. Each item is a hash reference, the keys of the
hash are C<srcm> (source mention object), C<tgtm> (target mention object),
and C<type> (string type of the bridging relation). At most one relation
between any pair of entities is allowed.

=back

=head1 METHODS

=over

=item my $mention = $eset->get_mention_by_thead($tnode);

If there is a mention for the given t-node, return it; otherwise return undef.

=item my $mention = $eset->create_mention($tnode);

Creates a new mention with the given t-node as the head. Will fail if the
t-node already has another mention.

=item my $mention = $eset->get_or_create_mention_for_thead($tnode);

Combination of C<get_mention_by_thead()> and C<create_mention()>. If the
t-node already has a mention, it returns it, otherwise it creates a new one
and returns it.

=item my @mentions = $eset->get_mentions_in_bundle($bundle);

Returns all mentions in the set that have their t-head in a particular bundle.
Use C<$node->get_bundle()> if you want to get mentions in the same sentence as
C<$node>.

=item $eset->remove_mention($mention);

Removes a mention from the set. This may result in removing an entity, if it
was a singleton. Bridging relations starting or ending at the mention will be
removed, too (they will not be moved to another mention of the same entity).
The t-node that serves as the head of the mention will stay untouched in the
tree.

=item $eset->merge_entities ($e1, $e2);

This function should be called when a coreference link is discovered between
mentions of two different entities. Mentions of C<$e2> will be moved to C<$e1>
and C<$e2> will be destroyed.

=item $eset->add_bridging ($src_mention, $tgt_mention, $relation_type);

Registers a new bridging relation. Although it is defined using mentions,
it is understood as a relation between two entities and it will not be added
if there is another relation between the same entities already. The relation
is typed and directed (e.g., the entity of the source mention is a subset of
the entity of the target mention).

=item $eset->get_bridging_starting_at_mention ($src_mention);

Returns an array of bridging hashes (with keys C<srcm> for source mention,
C<tgtm> for target mention, and C<type> for bridging relation type) containing
all bridging relations that start at the given entity mention. The array is
sorted by target entity ids. This is useful when the output is being prepared
(in CorefUD, bridging relations are stored at source mentions).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
