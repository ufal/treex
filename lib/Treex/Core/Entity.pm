package Treex::Core::Entity;

use utf8;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Node::T;



has 'eset'     => (is => 'rw', isa => 'Maybe[Treex::Core::EntitySet]', documentation => 'Refers to the set of all entities in the current document.');
has 'mentions' => (is => 'rw', isa => 'HashRef', default => sub {{}}, documentation => 'Hash holding references to EntityMention objects, i.e., all mentions of the entity, indexed by the id of the thead node.');
has 'id'       => (is => 'rw', isa => 'Str', documentation => 'Unique id of the entity, typically combination of document id and numeric entity index.');
has 'type'     => (is => 'rw', isa => 'Str', documentation => 'Optional entity type. May be learned from some coreference links (Spec vs. Gen). All links between mentions of one entity should have either no type or the same type, but sometimes there are conflicts because of annotation inconsistencies.');



#------------------------------------------------------------------------------
# If we did not know the type of the entity and we are now provided with a new
# (non-empty) type, set it. If we already knew the type and we are now provided
# with a different one (which could happen due to annotation inconsistencies),
# resolve the conflict.
#------------------------------------------------------------------------------
sub reconsider_type
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $new_type = shift;
    # If the new type is undefined or empty, do not do anything.
    return if(!defined($new_type) || $new_type eq '');
    # Now the new type is non-empty. If the old type was undefined, just set it.
    if(!$self->type())
    {
        $self->set_type($new_type);
    }
    else
    {
        # So we already had a type. If it was the same, fine. But if it was
        # different, we must resolve the conflict.
        if($new_type ne $self->type())
        {
            # The conflict can be only between 'gen' and 'spec'. We will give priority to 'gen'.
            # (Anja says that the annotators looked specifically for 'gen', then batch-annotated everything else as 'spec'.)
            # We could also issue a warning but it does not seem very helpful.
            # log_warn("Conflict in entity types from different sources: '$new_type' vs. '".$self->type()."'.");
            $self->set_type('gen');
        }
    }
    return $self->type();
}



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
# mention. The mention will belong to the current entity. This function does
# not examine the t-node's coreference links. If we later do it, we may find
# out that this entity has to be merged with another.
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
    my $mention = new Treex::Core::EntityMention('thead' => $thead, 'entity' => $self);
    $self->{mentions}{$thead->id()} = $mention;
    return $mention;
}



#------------------------------------------------------------------------------
# Returns a textual representation of the entity. Useful for debugging.
#------------------------------------------------------------------------------
sub as_string
{
    my $self = shift;
    my $id = $self->id() // 'undef';
    return "$self with id $id";
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Entity

=head1 DESCRIPTION

An C<Entity> is a set of mentions (C<Treex::Core::EntityMention>) referring to
the entity in the text. The heads of these mentions are connected by
coreference links in the tectogrammatical representation. There must be at
least one mention, otherwise the entity cannot exist. If there is exactly one
mention, the entity (and the mention) is a singleton.

=head1 ATTRIBUTES

=over

=item eset

Reference to the C<EntitySet> object to which this entity belongs.

=item mentions

A non-empty hash of C<EntityMention> objects, indexed by the id of the thead node.

=item id

Unique id of the entity, typically combination of document id and numeric
entity index.

=item type

Optional string characterizing the type of the entity. We currently take them
from types stored with coreference links in the t-layer of PDT. The values are
C<Gen> and C<Spec>.

=back

=head1 METHODS

=over

=item my $mention = $eset->get_mention_by_thead($tnode);

If there is a mention for the given t-node, return it; otherwise return undef.

=item my $mention = $eset->create_mention($tnode);

Creates a new mention with the given t-node as the head. Will fail if the
t-node already has another mention.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
