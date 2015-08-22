package Treex::Core::Phrase::PP;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;

extends 'Treex::Core::Phrase::NTerm';



has 'head' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1,
    writer   => '_set_head',
    reader   => 'head'
);

has 'nonhead_children' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] }
);



#------------------------------------------------------------------------------
# Returns the head node of the phrase. For nonterminal phrases this recursively
# returns head node of their head child.
#------------------------------------------------------------------------------
sub node
{
    my $self = shift;
    return $self->head()->node();
}



#------------------------------------------------------------------------------
# Returns the type of the dependency relation of the phrase to the governing
# phrase. A general nonterminal phrase has the same deprel as its head child.
#------------------------------------------------------------------------------
sub deprel
{
    my $self = shift;
    return $self->head()->deprel();
}



#------------------------------------------------------------------------------
# Sets a new head child for this phrase. The new head must be already a child
# of this phrase. The old head will become an ordinary non-head child.
#------------------------------------------------------------------------------
sub set_head
{
    my $self = shift;
    my $new_head = shift; # Treex::Core::Phrase
    my $old_head = $self->head();
    return if ($new_head == $old_head);
    # Remove the new head from the list of non-head children.
    # (The method will also verify that it is defined and is my child.)
    $self->_remove_child($new_head);
    # Add the old head to the list of non-head children.
    $self->_add_child($old_head);
    # Finally, set the new head, using the private bare setter.
    $self->_set_head($new_head);
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
  use Treex::Core::Phrase::NTerm;

  my $document = new Treex::Core::Document;
  my $bundle   = $document->create_bundle();
  my $zone     = $bundle->create_zone('en');
  my $root     = $zone->create_atree();
  my $node     = $root->create_child();
  my $tphrase  = new Treex::Core::Phrase::Term ('node' => $node);
  my $ntphrase = new Treex::Core::Phrase::NTerm ('head' => $tphrase);

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

It is questionable whether this phrase should actually be considered an
extension of C<Phrase::NTerm>. Because we would have to override the C<head>
attribute. Here it is not an attribute, merely a function. But we need two new
attributes, C<preposition> and C<argument>. These should be separated from the
ordinary children in the same fashion as C<head> is separated from the other
children of C<Phrase::NTerm>. We may also need an attribute for the current
head style (whether C<head()> should return the preposition or the argument).

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
