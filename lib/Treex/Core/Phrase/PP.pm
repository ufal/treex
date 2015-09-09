package Treex::Core::Phrase::PP;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;

extends 'Treex::Core::Phrase::BaseNTerm';



has 'prep' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_prep',
    reader   => 'prep'
);

has 'arg' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_arg',
    reader   => 'arg'
);

has 'prep_is_head' =>
(
    is       => 'rw',
    isa      => 'Bool',
    required => 1
);



#------------------------------------------------------------------------------
# After the object is constructed, this block makes sure that the core children
# refer back to it as their parent.
#------------------------------------------------------------------------------
BUILD
{
    my $self = shift;
    if(defined($self->prep()->parent()) || defined($self->arg()->parent()))
    {
        confess("The core child already has another parent");
    }
    $self->prep()->_set_parent($self);
    $self->arg()->_set_parent($self);
}



#------------------------------------------------------------------------------
# Returns the head child of the phrase. Depending on the current preference,
# it is either the preposition or its argument.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    confess('Dead') if($self->dead());
    return $self->prep_is_head() ? $self->prep() : $self->arg();
}



#------------------------------------------------------------------------------
# Returns the list of non-head children of the phrase, i.e. the dependents plus
# either the preposition or the argument (whichever is currently not the head).
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = (($self->prep_is_head() ? $self->arg() : $self->prep()), $self->dependents());
    return _order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the list of the children of the phrase that are not dependents, i.e.
# both the preposition and the argument.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = ($self->prep(), $self->arg());
    return _order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Replaces one of the core children (preposition or argument) by another
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
    if($old_child == $self->prep())
    {
        $self->_set_prep($new_child);
    }
    elsif($old_child == $self->arg())
    {
        $self->_set_arg($new_child);
    }
    else
    {
        confess("The replacement child is not in my core");
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
  my $pphrase  = new Treex::Core::Phrase::PP ('prep' => $prepphr, 'arg' => $argphr, 'prep_is_head' => 1);

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

=item prep

A sub-C<Phrase> of this phrase that contains the preposition (or another
function word if this is not a true prepositional phrase).

=item arg

A sub-C<Phrase> (typically a noun phrase) of this phrase that contains the
argument of the preposition (or of the other function word if this is not
a true prepositional phrase).

=item prep_is_head

Boolean attribute that defines the currently preferred annotation style.
C<True> means that the preposition is considered the head of the phrase.
C<False> means that the argument is the head.

=back

=head1 METHODS

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase
(in the sense of dependency syntax).
Depending on the current preference, it is either the preposition or its
argument.

=item nonhead_children

Returns the list of non-head children of the phrase, i.e. the dependents plus either
the preposition or the argument (whichever is currently not the head).

=item core_children

Returns the list of the children of the phrase that are not dependents, i.e. both the
preposition and the argument.

=item replace_core_child

Replaces one of the core children (preposition or argument) by another
phrase. This is used when we want to transform the child to a different class
of phrase. The replacement must not have a parent yet.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
