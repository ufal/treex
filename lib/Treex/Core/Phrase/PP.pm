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
# Returns the head child of the phrase. Depending on the current preference,
# it is either the preposition or its argument.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    return $self->prep_is_head() ? $self->prep() : $self->arg();
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
  #################################!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! TODO
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

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
