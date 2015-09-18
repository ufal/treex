package Treex::Core::Phrase::PP;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;

extends 'Treex::Core::Phrase::BaseNTerm';



has 'fun' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_fun',
    reader   => 'fun'
);

has 'arg' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_arg',
    reader   => 'arg'
);

has 'fun_is_head' =>
(
    is       => 'rw',
    isa      => 'Bool',
    required => 1
);

has 'deprel_at_fun' =>
(
    is       => 'rw',
    isa      => 'Bool',
    required => 1,
    documentation =>
        'Where (at what core child) is the label of the relation between this '.
        'phrase and its parent? It is either at the function word or at the '.
        'argument, regardless which of them is the head.'
);



#------------------------------------------------------------------------------
# After the object is constructed, this block makes sure that the core children
# refer back to it as their parent.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    if(defined($self->fun()->parent()) || defined($self->arg()->parent()))
    {
        confess("The core child already has another parent");
    }
    $self->fun()->_set_parent($self);
    $self->arg()->_set_parent($self);
}



#------------------------------------------------------------------------------
# Returns the head child of the phrase. Depending on the current preference,
# it is either the function word or its argument.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->fun_is_head() ? $self->fun() : $self->arg();
}



#------------------------------------------------------------------------------
# Returns the list of non-head children of the phrase, i.e. the dependents plus
# either the function word or the argument (whichever is currently not the head).
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = (($self->fun_is_head() ? $self->arg() : $self->fun()), $self->dependents());
    return $self->_order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the list of the children of the phrase that are not dependents, i.e.
# both the function word and the argument.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = ($self->fun(), $self->arg());
    return $self->_order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the type of the dependency relation of the phrase to the governing
# phrase. A prepositional phrase has the same deprel as one of its core
# children. Depending on the current preference it is either the function word or
# the argument. This is not necessarily the same child that is the current
# head. For example, in the Prague annotation style, the preposition is head
# but its deprel is always 'AuxP' while the real deprel of the whole phrase is
# stored at the argument.
#------------------------------------------------------------------------------
sub deprel
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->deprel_at_fun() ? $self->fun()->deprel() : $self->arg()->deprel();
}



#------------------------------------------------------------------------------
# Sets a new type of the dependency relation of the phrase to the governing
# phrase. For PPs the label is propagated to one of the core children.
# Depending on the current preference it is either the function word or the
# argument. This is not necessarily the same child that is the current head.
# The label is not propagated to the underlying dependency tree
# (the project_dependencies() method would have to be called to achieve that).
#------------------------------------------------------------------------------
sub set_deprel
{
    my $self = shift;
    confess('Dead') if($self->dead());
    $self->deprel_at_fun() ? $self->fun()->set_deprel(@_) : $self->arg()->set_deprel(@_);
}



#------------------------------------------------------------------------------
# Replaces one of the core children (function word or argument) by another
# phrase. This is used when we want to transform the child to a different class
# of phrase. The replacement must not have a parent yet.
#------------------------------------------------------------------------------
sub replace_core_child
{
    my $self = shift;
    my $old_child = shift; # Treex::Core::Phrase
    my $new_child = shift; # Treex::Core::Phrase
    confess('Dead') if($self->dead());
    $self->_check_old_new_child($old_child, $new_child);
    $old_child->_set_parent(undef);
    $new_child->_set_parent($self);
    if($old_child == $self->fun())
    {
        $self->_set_fun($new_child);
    }
    elsif($old_child == $self->arg())
    {
        $self->_set_arg($new_child);
    }
    else
    {
        confess("The child to be replaced is not in my core");
    }
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::PP

=head1 SYNOPSIS

  use Treex::Core::Document;
  use Treex::Core::Phrase::Term;
  use Treex::Core::Phrase::PP;

  my $document = new Treex::Core::Document;
  my $bundle   = $document->create_bundle();
  my $zone     = $bundle->create_zone('en');
  my $root     = $zone->create_atree();
  my $prep     = $root->create_child();
  my $noun     = $prep->create_child();
  $prep->set_deprel('AuxP');
  $noun->set_deprel('Adv');
  my $prepphr  = new Treex::Core::Phrase::Term ('node' => $prep);
  my $argphr   = new Treex::Core::Phrase::Term ('node' => $noun);
  my $pphrase  = new Treex::Core::Phrase::PP ('fun' => $prepphr, 'arg' => $argphr, 'fun_is_head' => 1);

=head1 DESCRIPTION

C<Phrase::PP> (standing for I<prepositional phrase>) is a special case of
C<Phrase::NTerm>. The model example is a preposition (possibly compound) and
its argument (typically a noun phrase), plus possible dependents of the whole,
such as emphasizers or punctuation. However, it can be also used for
subordinating conjunctions plus relative clauses, or for any pair of a function
word and its (one) argument.

While we know the two key children (let's call them the preposition and the
argument), we do not take for fixed which one of them is the head (but the head
is indeed one of these two, and not any other child). Depending on the
preferred annotation style, we can pick the preposition or the argument as the
current head.

=head1 ATTRIBUTES

=over

=item fun

A sub-C<Phrase> of this phrase that contains the preposition (or another
function word if this is not a true prepositional phrase).

=item arg

A sub-C<Phrase> (typically a noun phrase) of this phrase that contains the
argument of the preposition (or of the other function word if this is not
a true prepositional phrase).

=item fun_is_head

Boolean attribute that defines the currently preferred annotation style.
C<True> means that the function word is considered the head of the phrase.
C<False> means that the argument is the head.

=item deprel_at_fun

Where (at what core child) is the label of the relation between this phrase and
its parent? It is either at the function word or at the argument, regardless
which of them is the head.

=back

=head1 METHODS

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase
(in the sense of dependency syntax).
Depending on the current preference, it is either the function word or its
argument.

=item nonhead_children

Returns the list of non-head children of the phrase, i.e. the dependents plus either
the function word or the argument (whichever is currently not the head).

=item core_children

Returns the list of the children of the phrase that are not dependents, i.e. both the
function word and the argument.

=item deprel

Returns the type of the dependency relation of the phrase to the governing
phrase. A prepositional phrase has the same deprel as one of its core
children. Depending on the current preference it is either the function word or
the argument. This is not necessarily the same child that is the current
head. For example, in the Prague annotation style, the preposition is head
but its deprel is always C<AuxP> while the real deprel of the whole phrase is
stored at the argument.

=item set_deprel

Sets a new type of the dependency relation of the phrase to the governing
phrase. For PPs the label is propagated to one of the core children.
Depending on the current preference it is either the function word or the
argument. This is not necessarily the same child that is the current head.
The label is not propagated to the underlying dependency tree
(the project_dependencies() method would have to be called to achieve that).

=item replace_core_child

Replaces one of the core children (function word or argument) by another
phrase. This is used when we want to transform the child to a different class
of phrase. The replacement must not have a parent yet.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
