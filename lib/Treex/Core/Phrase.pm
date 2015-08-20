package Treex::Core::Phrase;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;



has 'parent' =>
(
    is       => 'rw',
    isa      => 'Maybe[Treex::Core::Phrase]',
    writer   => '_set_parent',
    reader   => 'parent',
    default  => undef
);



#------------------------------------------------------------------------------
# Sets a new parent for this phrase. Unlike the bare setter _set_parent(),
# this public method also takes care of the reverse links from the parent to
# the children.
#------------------------------------------------------------------------------
sub set_parent
{
    my $self = shift;
    my $new_parent = shift; # Treex::Core::Phrase::NTerm or undef
    my $old_parent = $self->parent();
    # Say the old parent good bye.
    if(defined($old_parent))
    {
        $old_parent->_remove_child($self);
    }
    # Set the new parent before we call its _add_child() method so that it can verify it has been called from here.
    $self->_set_parent($new_parent);
    # Say the new parent hello.
    if(defined($new_parent))
    {
        $new_parent->_add_child($self);
    }
}



#------------------------------------------------------------------------------
# Returns the head node of the phrase. For terminal phrases this should just
# return their node attribute. For nonterminal phrases this should return the
# node of their head child. This is an abstract method that must be defined in
# every derived class.
#------------------------------------------------------------------------------
sub node
{
    my $self = shift;
    confess("The node() method is not implemented");
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase

=head1 DESCRIPTION

A C<Phrase> is a concept defined on top of dependency trees and subtrees
(where a subtree contains a node and all its descendants, not just any arbitrary subset of nodes).
Similarly to the Chomsky's hierarchy of formal grammars, there are two main types of phrases:
I<terminal> and I<nonterminal>.
Furthermore, there may be subtypes of the nonterminal type with special behavior.

A B<terminal phrase> contains just one C<Node> (which typically corresponds to a surface token).

A B<nonterminal phrase> does not directly contain any C<Node> but it contains
one or more (usually at least two) sub-phrases.
The hierarchy of phrases and their sub-phrases is also a tree structure.
In the typical case there is a relation between the tree of phrases and the underlying dependency
tree, but the rules governing this relation are not fixed.

Phrases help us model situations that are difficult to model in the dependency tree alone.
We can encode multiple levels of “tightness” of relations between governors and dependents.
In particular we can distinguish between dependents that modify the whole phrase (shared modifiers)
and those that modify only the head of the phrase (private modifiers).

This is particularly useful for various tree transformations and conversions between annotation
styles (such as in the HamleDT blocks).
The idea is that we will first construct a phrase tree based on the existing dependency tree,
then we will perform transformations on the phrase tree
and finally we will create new dependency relations based on the phrase tree and
on the rules defined by the desired annotation style.
Phrase is a temporary internal structure that will not be saved in the Treex format on the disk.

Every phrase knows its parent (superphrase) and, if it is nonterminal, its children (subphrases).
It also knows which of the children is the I<head> (as long as there are children, there is always
one and only one head child).
The phrase can also return its head node. For terminal phrases, this is the node they enwrap.
For nonterminal phrases, this is defined recursively as the head node of their head child phrase.

Every phrase also has a dependency relation label I<(deprel)>.
These labels are analogous to deprels of nodes in dependency trees.
Most of them are just taken from the underlying dependency tree and they are propagated back when
new dependency structure is shaped after the phrases; however, some labels may have special
meaning even for the C<Phrase> objects. They help recognize special types of nonterminal phrases,
such as coordinations.
If the phrase is the head of its parent phrase, its deprel is identical to the deprel of its parent.
Otherwise, the deprel represents the dependency relation between the phrase and the head of its parent.

=head1 METHODS

=over

=item $phrase->set_parent ($nonterminal_phrase);

Sets a new parent for this phrase. The parent phrase must be a L<nonterminal|Treex::Core::Phrase::NTerm>.
This phrase will become its new I<non-head> child.
The new parent may also be undefined, which means that the current phrase will
be disconnected from the phrase structure (but it will keeep its own children,
if any).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
