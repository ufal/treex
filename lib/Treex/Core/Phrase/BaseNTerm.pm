package Treex::Core::Phrase::BaseNTerm;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase';



has 'dependents' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] }
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
# Returns the head child of the phrase. This is an abstract method that must be
# defined in every derived class.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    confess("The head() method is not implemented");
}



#------------------------------------------------------------------------------
# Returns the non-head children of the phrase. By default these are the
# dependents. However, in special nonterminal phrases there may be children
# that are neither head nor dependents.
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->dependents();
}



#------------------------------------------------------------------------------
# Returns the children of the phrase that are not dependents. By default this
# is just the head child. However, in special nonterminal phrases there may be
# other children that have a special status but are not the current head.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return ($self->head());
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
    my $nhc = $self->dependents();
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
    my $nhc = $self->dependents();
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

=item dependents

Array of sub-C<Phrase>s (children) of this phrase that do not belong to the
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

=item nonhead_children

Returns the non-head children of the phrase. By default these are the
dependents. However, in special nonterminal phrases there may be children
that are neither head nor dependents.

=item core_children

Returns the children of the phrase that are not dependents. By default this
is just the head child. However, in specialized nonterminal phrases there may be
other children that have a special status but are not the current head.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
