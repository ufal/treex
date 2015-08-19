package Treex::Core::Phrase;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;



has 'parent' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    writer   => '_set_parent',
    reader   => 'parent'
);



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



#------------------------------------------------------------------------------
# Wraps a node (and its subtree, if any) in a phrase.
#------------------------------------------------------------------------------
sub build_phrase
{
    my $self = shift;
    my $node = shift; # Treex::Core::Node
    my @nchildren = $node->children();
    my $phrase = new Treex::Core::Phrase::Term('node' => $node);
    if(@nchildren)
    {
        my @pchildren = ($phrase);
        foreach my $nchild (@nchildren)
        {
            my $pchild = $self->build_phrase($nchild);
            push(@pchildren, $pchild);
        }
        ###!!! Případně by se dala zkonstruovat s jedním dítětem (tím terminálem) a ostatní děti pak vkládat v cyklu nějakou metodou add_child().
        ###!!! Nebo raději udělat _add_child() neveřejné a jako hlavní metodu dát set_parent() u dítěte, stejně jako je to u závislostních stromů?
        $phrase = new Treex::Core::Phrase::NTerm('children' => \@pchildren);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Disconnects a phrase from its parent phrase. Discards the link from child to
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
        # Moose will not allow _set_parent(undef) because undef is not of class Treex::Core::Phrase. ###!!! a co Maybe deklarace?
        # We will create a dummy object instead. Parent will have the only reference to it and Perl will be able to discard it.
        # I am sure that there must be a better way to do this but I don't know how.
        $self->_set_parent(Treex::Core::Phrase->new);
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
            log_fatal('Parent phrase does not know me as its shared modifier.');
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
        $child->_set_parent(Treex::Core::Phrase->new); # disconnect from me
    }
    splice(@{$smod});
    return;
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

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
