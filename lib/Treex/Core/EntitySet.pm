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
    my $entity = new Treex::Core::Entity('eset' => $self);
    push(@{$self->{entities}}, $entity);
    my $mention = $entity->create_mention($thead);
    $self->{mentions}{$thead->id()} = $mention;
    return $mention;
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
    # If e1 does not have type and e2 does, copy it.
    if($e2->type())
    {
        if($e1->type())
        {
            my $t1 = $e1->type();
            my $t2 = $e2->type();
            log_warn("Merging entities of different types: '$t1' vs. '$t2'.");
        }
        else
        {
            $e1->set_type($e2->type());
        }
    }
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

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
