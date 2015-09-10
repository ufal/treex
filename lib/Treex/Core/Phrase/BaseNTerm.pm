package Treex::Core::Phrase::BaseNTerm;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase';



has '_dependents_ref' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] },
    documentation => 'The public should not access directly the array reference. '.
        'They may use the public method dependents() to get the list.'
);

has 'dead' =>
(
    is       => 'rw',
    isa      => 'Bool',
    writer   => '_set_dead',
    reader   => 'dead',
    default  => 0,
    documentation => 'Most non-terminal phrases cannot exist without children. '.
        'If we want to change the class of a non-terminal phrase, we construct '.
        'an object of the new class and move the children there from the old '.
        'one. But the old object will not be physically destroyed until it '.
        'gets out of scope. So we will mark it as “dead”. If anyone tries to '.
        'use the dead object, an exception will be thrown.'
);



#------------------------------------------------------------------------------
# Tells whether this phrase is terminal. We could probably use the Moose's
# methods to query the class name but this will be more convenient.
#------------------------------------------------------------------------------
sub is_terminal
{
    my $self = shift;
    return 0;
}



#------------------------------------------------------------------------------
# Returns the head child of the phrase. This is an abstract method that must be
# defined in every derived class.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    confess("The head() method is not implemented");
}



#------------------------------------------------------------------------------
# Figures out whether an ordered list of children is required. Allows both hash
# and non-hash notations, i.e.
#   my @c = $p->dependents({'ordered' => 1});
#   my @c = $p->dependents('ordered' => 1);
#   my @c = $p->dependents('ordered');
#------------------------------------------------------------------------------
sub _order_required
{
    my @parray = @_;
    return 0 unless(@parray);
    return $parray[0]->{ordered} if(ref($parray[0]) eq 'HASH');
    my %phash = @_;
    if(exists($phash{ordered}))
    {
        # To accommodate the $p->dependents('ordered') calling style, even undefined value will count as true.
        if(defined($phash{ordered}) && $phash{ordered}==0)
        {
            return 0;
        }
        return 1;
    }
    return 0;
}



#------------------------------------------------------------------------------
# Sorts a list of phrases according to the word order of their head nodes.
#------------------------------------------------------------------------------
sub order_phrases
{
    my $self = shift;
    return sort {$a->ord() <=> $b->ord()} (@_);
}



#------------------------------------------------------------------------------
# Returns the list of dependents of the phrase. The only difference from the
# getter _dependents_ref() is that the getter returns a reference to the array
# of dependents, while this method returns a list of dependents, hence it is
# more similar to the other methods that return lists of children.
#------------------------------------------------------------------------------
sub dependents
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @dependents = @{$self->_dependents_ref()};
    return _order_required(@_) ? $self->order_phrases(@dependents) : @dependents;
}



#------------------------------------------------------------------------------
# Returns the list of non-head children of the phrase. By default these are the
# dependents. However, in special nonterminal phrases there may be children
# that are neither head nor dependents.
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->dependents(@_);
}



#------------------------------------------------------------------------------
# Returns the list of the children of the phrase that are not dependents. By
# default this is just the head child. However, in special nonterminal phrases
# there may be other children that have a special status but are not the
# current head.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return ($self->head());
}



#------------------------------------------------------------------------------
# Returns the list of all children of the phrase, i.e. core children and
# dependents.
#------------------------------------------------------------------------------
sub children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = ($self->core_children(), $self->dependents());
    return _order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the head node of the phrase. For nonterminal phrases this recursively
# returns head node of their head child.
#------------------------------------------------------------------------------
sub node
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->head()->node();
}



#------------------------------------------------------------------------------
# Returns the type of the dependency relation of the phrase to the governing
# phrase. A general nonterminal phrase has the same deprel as its head child.
#------------------------------------------------------------------------------
sub deprel
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->head()->deprel();
}



#------------------------------------------------------------------------------
# Adds a child phrase (subphrase). By default, the new child will not be head,
# it will be an ordinary modifier. This is a private method that should be
# called only from the public method Phrase::set_parent().
#------------------------------------------------------------------------------
sub _add_child
{
    my $self = shift;
    my $new_child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    # If we are called correctly from Phrase::set_parent(), then the child already knows about us.
    if(!defined($new_child) || !defined($new_child->parent()) || $new_child->parent() != $self)
    {
        confess("The child must point to the parent first. This private method must be called only from Phrase::set_parent()");
    }
    my $nhc = $self->_dependents_ref();
    push(@{$nhc}, $new_child);
}



#------------------------------------------------------------------------------
# Removes a child phrase (subphrase). Only non-head children can be removed
# this way. If the head is to be removed, it must be first replaced by another
# child; or the whole nonterminal phrase must be destroyed. This is a private
# method that should be called only from the public method Phrase::set_parent().
#------------------------------------------------------------------------------
sub _remove_child
{
    my $self = shift;
    my $child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    if(!defined($child) || !defined($child->parent()) || $child->parent() != $self)
    {
        confess("The child does not think I'm its parent");
    }
    if(any {$_ == $child} ($self->core_children()))
    {
        confess("Cannot remove the head child or any other core child");
    }
    my $nhc = $self->_dependents_ref();
    my $found = 0;
    for(my $i = 0; $i <= $#{$nhc}; $i++)
    {
        if($nhc->[$i] == $child)
        {
            $found = 1;
            splice(@{$nhc}, $i, 1);
            last;
        }
    }
    if(!$found)
    {
        confess("Could not find the phrase among my non-head children");
    }
}



#------------------------------------------------------------------------------
# Common validation for replace_child() and replace_core_child(). May throw
# exceptions.
#------------------------------------------------------------------------------
sub _check_old_new_child
{
    my $self = shift;
    my $old_child = shift; # Treex::Core::Phrase
    my $new_child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    if(!defined($old_child) || !defined($old_child->parent()) || $old_child->parent() != $self)
    {
        confess("The child to be replaced does not think I'm its parent");
    }
    if(!defined($new_child))
    {
        confess("The replacement child is not defined");
    }
    if(defined($new_child->parent()))
    {
        if($new_child->parent() == $self)
        {
            confess("The replacement already is my child");
        }
        else
        {
            confess("The replacement child already has a parent");
        }
    }
}



#------------------------------------------------------------------------------
# Replaces a child by another phrase. This method will work with any child,
# including the core children. The core children cannot be undefined but if we
# immediately replace them by a new child, the phrase will remain valid.
#------------------------------------------------------------------------------
sub replace_child
{
    my $self = shift;
    my $old_child = shift; # Treex::Core::Phrase
    my $new_child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    $self->_check_old_new_child($old_child, $new_child);
    # If the child is dependent, we can do it here. If it is a core child,
    # we need a subclass to decide what to do.
    my $nhc = $self->_dependents_ref();
    for(my $i = 0; $i <= $#{$nhc}; $i++)
    {
        if($nhc->[$i] == $old_child)
        {
            splice(@{$nhc}, $i, 1, $new_child);
            $old_child->_set_parent(undef);
            $new_child->_set_parent($self);
            return;
        }
    }
    # If we are here, we did not find the old child among the dependents.
    # Thus it has to be a core child.
    $self->replace_core_child($old_child, $new_child);
}



#------------------------------------------------------------------------------
# Replaces a core child by another phrase. This is an abstract method that must
# be defined in every derived class.
#------------------------------------------------------------------------------
sub replace_core_child
{
    my $self = shift;
    confess("The replace_core_child() method is not implemented");
}



#------------------------------------------------------------------------------
# Detaches all children (including core children) and then marks itself as dead
# so that it cannot be used any more. This method should be called when we want
# to replace a non-terminal phrase by a new phrase of a different class. The
# method will not detach the dying phrase from its parent! That could kill the
# parent too (if the dying phrase is a core child) but we probably want the
# parent to survive and to replace the dying child by a new phrase we create.
# However, it is the caller's responsibility to modify the parent immediately.
#------------------------------------------------------------------------------
sub detach_children_and_die
{
    my $self = shift;
    # Visit all children and tell them they have no parent now. We cannot use
    # the public method set_parent() because it will call our method _remove_child()
    # and that only works for non-core children. (Besides, we want to destroy
    # our links to children all at once. The _remove_child() method would be
    # unnecessarily slow for that purpose, as it works with only one child and
    # has to find it first.) Thus we will directly modify the one-way link via
    # _set_parent().
    my @children = $self->children();
    foreach my $child (@children)
    {
        $child->_set_parent(undef);
    }
    # Remove the references leading from this phrase to its dependents.
    splice(@{$self->_dependents_ref()});
    # We cannot remove the references to the core children because we do not
    # know how many core children there are and how they are accessed, and
    # they cannot be undefined anyway. However, we will mark this phrase as
    # dead, so it cannot be used until it is physically destroyed by Perl.
    $self->_set_dead(1);
    return @children;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::BaseNTerm

=head1 DESCRIPTION

C<BaseNTerm> is an abstract class that defines the basic interface of
nonterminal phrases. The general nonterminal phrase, C<NTerm>, is derived from
C<BaseNTerm>. So are some special cases of nonterminals, such as C<PP>.
(They cannot be derived from C<NTerm> because they implement certain parts
of the interface differently.)

See also L<Treex::Core::Phrase> and L<Treex::Core::Phrase::NTerm>.

=head1 ATTRIBUTES

=over

=item _dependents_ref

Reference to array of sub-C<Phrase>s (children) of this phrase that do not belong to the
core of the phrase. By default the core contains only the head child. However,
some specialized subclasses may define a larger core where two or more
children have a special status, but only one of them can be the head.

=item dead

Most non-terminal phrases cannot exist without children.
If we want to change the class of a non-terminal phrase, we construct
an object of the new class and move the children there from the old
one. But the old object will not be physically destroyed until it
gets out of scope. So we will mark it as “dead”. If anyone tries to
use the dead object, an exception will be thrown.

=back

=head1 METHODS

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase (in the sense of dependency syntax).
A general C<NTerm> phrase just has a C<head> attribute.
Special cases of nonterminals may have multiple children with special behavior,
and they may choose which one of these children shall be head under the current
annotation style.

=item dependents

Returns the list of dependents of the phrase. The only difference from the
getter C<_dependents_ref()> is that the getter returns a reference to the array
of dependents, while this method returns a list of dependents. Hence this method is
more similar to the other methods that return lists of children.

=item nonhead_children

Returns the list of non-head children of the phrase. By default these are the
dependents. However, in special nonterminal phrases there may be children
that are neither head nor dependents.

=item core_children

Returns the list of the children of the phrase that are not dependents. By default this
is just the head child. However, in specialized nonterminal phrases there may be
other children that have a special status but are not the current head.

=item children

Returns the list of all children of the phrase, i.e. core children and
dependents.

=item order_phrases

Sorts a list of phrases according to the word order of their head nodes.
All methods that return lists of children (C<dependents()>, C<nonhead_children()>,
C<core_children()>, C<children()>) can be asked to sort the list using this
method. The following calling styles are possible:

  my @ordered_children = $phrase->children({'ordered' => 1});
  my @ordered_children = $phrase->children('ordered' => 1);
  my @ordered_children = $phrase->children('ordered');

=item replace_child

  $nonterminal->replace_child ($old_child, $new_child);

Replaces a child by another phrase. This method will work with any child,
including the core children. The core children cannot be undefined but if we
immediately replace them by a new child, the phrase will remain valid.

=item replace_core_child

Same as C<replace_child()> but used with core children only. If we know that we
are replacing a core child, it is more efficient to call directly this method.
If we do not know what type of child we have, we can call the more general
C<replace_child()> and it will decide.

C<BaseNTerm::replace_core_child()> is an abstract method that must be defined
in every derived class.

=item detach_children_and_die

  my $parent = $phrase->parent();
  my $replacement = new Treex::Core::Phrase::PP (...);
  my @children = $phrase->detach_children_and_die();
  $parent->replace_child ($phrase, $replacement);

Detaches all children (including core children) and then marks itself as dead
so that it cannot be used any more. This method should be called when we want
to replace a non-terminal phrase by a new phrase of a different class. The
method will not detach the dying phrase from its parent! That could kill the
parent too (if the dying phrase is a core child) but we probably want the
parent to survive and to replace the dying child by a new phrase we create.
However, it is the caller's responsibility to modify the parent immediately.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
