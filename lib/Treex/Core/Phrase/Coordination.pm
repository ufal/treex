package Treex::Core::Phrase::Coordination;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;

extends 'Treex::Core::Phrase::BaseNTerm';



has '_conjuncts_ref' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] },
    documentation => 'The public should not access directly the array reference. '.
        'They may use the public method conjuncts() to get the list.'
);

has '_coordinators_ref' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] },
    documentation => 'Coordinating conjunctions and similarly working words but not punctuation. '.
        'The public should not access directly the array reference. '.
        'They may use the public method coordinators() to get the list.'
);

has '_punctuation_ref' =>
(
    is       => 'ro',
    isa      => 'ArrayRef[Treex::Core::Phrase]',
    default  => sub { [] },
    documentation => 'Punctuation between conjuncts. '.
        'The public should not access directly the array reference. '.
        'They may use the public method punctuation() to get the list.'
);

has 'head_rule' =>
(
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    default  => 'first_conjunct',
    documentation =>
        'first_conjunct ..... first conjunct is the head (there is always at least one conjunct); '.
        'last_coordinator ... last coordinating conjunction, if any, is the head; '.
        '                     last punctuation is head in asyndetic coordination; '.
        '                     if there are neither conjunctions nor punctuation, the first conjunct is the head.'
);



#------------------------------------------------------------------------------
# After the object is constructed, this block makes sure that the core children
# refer back to it as their parent. Also, at least one conjunct is required and
# making the conjuncts parametr required is not enough to enforce that.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    # Check that there is at least one conjunct.
    if(scalar(@{$self->conjuncts()})==0)
    {
        confess("There must be at least one conjunct");
    }
    # Make sure that all core children refer to me as their parent.
    my @children = $self->core_children();
    foreach my $child (@children)
    {
        if(defined($child->parent()))
        {
            confess("The core child already has another parent");
        }
        $child->_set_parent($self);
    }
}



#------------------------------------------------------------------------------
# Returns the list of conjuncts in the coordination. The only difference from
# the getter _conjuncts_ref() is that the getter returns a reference to the
# array of conjuncts, while this method returns a list of conjuncts, hence it
# is more similar to the other methods that return lists of children.
#------------------------------------------------------------------------------
sub conjuncts
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @conjuncts = @{$self->_conjuncts_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@conjuncts) : @conjuncts;
}



#------------------------------------------------------------------------------
# Returns the list of coordinators. The only difference from the getter
# _coordinators_ref() is that the getter returns a reference to the array of
# coordinators, while this method returns a list, hence it is more similar to
# the other methods that return lists of children.
#------------------------------------------------------------------------------
sub coordinators
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @coordinators = @{$self->_coordinators_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@coordinators) : @coordinators;
}



#------------------------------------------------------------------------------
# Returns the list of punctuation symbols between conjuncts. The only
# difference from the getter _punctuation_ref() is that the getter returns a
# reference to the array, while this method returns a list, hence it is more
# similar to the other methods that return lists of children.
#------------------------------------------------------------------------------
sub punctuation
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @punctuation = @{$self->_punctuation_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@punctuation) : @punctuation;
}



#------------------------------------------------------------------------------
# Returns the head child of the phrase. Depending on the current preference,
# it is either the preposition or its argument.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my $rule = $self->head_rule();
    if($rule eq 'first_conjunct')
    {
        # There is always at least one conjunct.
        return ($self->conjuncts())[0];
    }
    elsif($rule eq 'last_coordinator')
    {
        # It is not guaranteed that there are coordinators or punctuation.
        my @coordinators = $self->coordinators('ordered' => 1);
        if(scalar(@coordinators) > 0)
        {
            return $coordinators[-1];
        }
        # No coordinators found. What about punctuation?
        my @punctuation = $self->punctuation('ordered' => 1);
        if(scalar(@punctuation) > 0)
        {
            return $punctuation[-1];
        }
        # No delimiters found. We have to pick a conjunct, whether we like it or not.
        return ($self->conjuncts())[0];
    }
    else
    {
        confess("Unknown head rule '$rule'");
    }
}



#------------------------------------------------------------------------------
# Returns the list of non-head children of the phrase, i.e. the dependents plus
# all core children except the one that currently serves as the head.
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my $head = $self->head();
    my @children = grep {$_ != $head} ($self->children());
    return _order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the list of the children of the phrase that are not dependents, i.e.
# all conjuncts, coordinators and punctuation.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    confess('Dead') if($self->dead());
    my @children = ($self->conjuncts(), $self->coordinators(), $self->punctuation());
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

=item _conjuncts_ref

Reference to array of sub-C<Phrase>s (children) that are coordinated in this
phrase. The conjuncts are counted among the I<core children> of C<Coordination>.
Every C<Coordination> must always have at least one conjunct.

=item _coordinators_ref

Reference to array of sub-C<Phrase>s (children) that act as coordinating conjunctions
and that are words, not punctuation.
The coordinators are counted among the I<core children> of C<Coordination>.
However, their presence is not required.

=item _punctuation_ref

Reference to array of sub-C<Phrase>s (children) that contain punctuation between
conjuncts.
The punctuation phrases are counted among the I<core children> of C<Coordination>.
However, their presence is not required.

=item head_rule

A string that says how the head of the coordination should be selected.
C<first_conjunct> means that the first conjunct is the head (there is always at
least one conjunct).
C<last_coordinator> means that the last coordinating conjunction, if any, is
the head; in asyndetic coordination (no conjunctions) the last punctuation
symbol is the head; if there are neither conjunctions nor punctuation, the
first conjunct is the head.

=back

=head1 METHODS

=over

=item head

A sub-C<Phrase> of this phrase that is at the moment considered the head phrase
(in the sense of dependency syntax). It depends on the current C<head_rule>.

=item conjuncts

Returns the list of conjuncts. The only difference from the
getter C<_conjuncts_ref()> is that the getter returns a reference to the array
of conjuncts, while this method returns a list of conjuncts. Hence this method is
more similar to the other methods that return lists of children.

=item coordinators

Returns the list of coordinating conjunctions (but not punctuation).
The only difference from the
getter C<_coordinators_ref()> is that the getter returns a reference to array,
while this method returns a list. Hence this method is
more similar to the other methods that return lists of children.

=item punctuation

Returns the list of punctuation symbols between conjuncts.
The only difference from the
getter C<_punctuation_ref()> is that the getter returns a reference to array,
while this method returns a list. Hence this method is
more similar to the other methods that return lists of children.

=item nonhead_children

Returns the list of non-head children of the phrase, i.e. the dependents plus
all core children except the one that currently serves as the head.

=item core_children

Returns the list of the children of the phrase that are not dependents, i.e.
all conjuncts, coordinators and punctuation.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
