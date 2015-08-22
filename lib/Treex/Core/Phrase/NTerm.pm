package Treex::Core::Phrase::NTerm;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase';



has 'head' =>
(
    is       => 'rw',
    isa      => 'Treex::Core::Phrase',
    required => 1
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
# Adds a child phrase (subphrase). By default, the new child will not be head,
# it will be an ordinary modifier. This is a private method that should be
# called only from the public method Phrase::set_parent().
#------------------------------------------------------------------------------
sub _add_child
{
    my $self = shift;
    my $new_child = shift; # Treex::Core::Phrase
    # If we are called correctly from Phrase::set_parent(), then the child already knows about us.
    if(!defined($new_child) || !defined($new_child->parent()) || $new_child->parent() != $self)
    {
        confess("The child must point to the parent first. This private method must be called only from Phrase::set_parent()");
    }
    my $nhc = $self->nonhead_children();
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
    if(!defined($child) || !defined($child->parent()) || $child->parent() != $self)
    {
        confess("The child does not think I'm its parent");
    }
    if($child == $self->head())
    {
        confess("Cannot remove the head child");
    }
    my $nhc = $self->nonhead_children();
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

Treex::Core::Phrase::NTerm

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

C<NTerm> is a nonterminal C<Phrase>. It contains (refers to) one or more child
C<Phrase>s.
See L<Treex::Core::Phrase> for more details.

=head1 ATTRIBUTES

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase (in the sense of dependency syntax).
Head is a special case of child (sub-) phrase. The (one) head must always exist; other children are optional.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
