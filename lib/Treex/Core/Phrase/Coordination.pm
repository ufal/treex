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
# This block will be called before object construction. It will modify and
# complete attribute list if needed. Then it will pass all the attributes to
# the constructor.
#------------------------------------------------------------------------------
around BUILDARGS => sub
{
    my $orig = shift;
    my $class = shift;
    # Call the default BUILDARGS in Moose::Object. It will take care of distinguishing between a hash reference and a plain hash.
    my $attr = $class->$orig(@_);
    if(defined($attr->{conjuncts}) && ref($attr->{conjuncts}) eq 'ARRAY')
    {
        $attr->{_conjuncts_ref} = $attr->{conjuncts};
    }
    if(defined($attr->{coordinators}) && ref($attr->{coordinators}) eq 'ARRAY')
    {
        $attr->{_coordinators_ref} = $attr->{coordinators};
    }
    if(defined($attr->{punctuation}) && ref($attr->{punctuation}) eq 'ARRAY')
    {
        $attr->{_punctuation_ref} = $attr->{punctuation};
    }
    return $attr;
};



#------------------------------------------------------------------------------
# After the object is constructed, this block makes sure that the core children
# refer back to it as their parent. Also, at least one conjunct is required and
# making the conjuncts parameter required is not enough to enforce that.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    # Check that there is at least one conjunct.
    if(scalar($self->conjuncts())==0)
    {
        log_fatal("There must be at least one conjunct");
    }
    # Make sure that all core children refer to me as their parent.
    my @children = $self->core_children();
    foreach my $child (@children)
    {
        if(defined($child->parent()))
        {
            log_fatal("The core child already has another parent");
        }
        $child->_set_parent($self);
    }
}



#------------------------------------------------------------------------------
# Tells whether this phrase is coordination. We could probably use the Moose's
# methods to query the class name but this will be more convenient.
#------------------------------------------------------------------------------
sub is_coordination
{
    my $self = shift;
    # Default is FALSE, to be overridden here.
    return 1;
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
    log_fatal('Dead') if($self->dead());
    my @conjuncts = @{$self->_conjuncts_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@conjuncts) : @conjuncts;
}



#------------------------------------------------------------------------------
# Adds a phrase as a new conjunct to this coordination. The phrase may be
# currently a dependent of another phrase and will be correctly re-linked.
# However, it must not be a core child of any phrase.
#------------------------------------------------------------------------------
sub add_conjunct
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $new_conjunct = shift;
    log_fatal('Dead') if($self->dead());
    # First make it my dependent. This ensures that the new conjunct is
    # correctly detached from its current parent, if any. If it is already my
    # dependent, nothing will happen. But if it is my or someone else's core
    # child, an exception will be thrown. The set_parent() method also checks
    # that no cycle will be created.
    $new_conjunct->set_parent($self);
    # Now remove it from my dependents and add it to my conjuncts.
    my $nhc = $self->_dependents_ref();
    my $found = 0;
    for(my $i = 0; $i <= $#{$nhc}; $i++)
    {
        if($nhc->[$i] == $new_conjunct)
        {
            $found = 1;
            splice(@{$nhc}, $i, 1);
            last;
        }
    }
    if(!$found)
    {
        log_fatal("Could not find the phrase among my non-core children");
    }
    # Add it to my conjuncts.
    my $cnj = $self->_conjuncts_ref();
    push(@{$cnj}, $new_conjunct);
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
    log_fatal('Dead') if($self->dead());
    my @coordinators = @{$self->_coordinators_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@coordinators) : @coordinators;
}



#------------------------------------------------------------------------------
# Adds a phrase as a new coordinator to this coordination. The phrase may be
# currently a dependent of another phrase and will be correctly re-linked.
# However, it must not be a core child of any phrase.
#------------------------------------------------------------------------------
sub add_coordinator
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $new_coordinator = shift;
    log_fatal('Dead') if($self->dead());
    # First make it my dependent. This ensures that the new coordinator is
    # correctly detached from its current parent, if any. If it is already my
    # dependent, nothing will happen. But if it is my or someone else's core
    # child, an exception will be thrown. The set_parent() method also checks
    # that no cycle will be created.
    $new_coordinator->set_parent($self);
    # Now remove it from my dependents and add it to my coordinators.
    my $nhc = $self->_dependents_ref();
    my $found = 0;
    for(my $i = 0; $i <= $#{$nhc}; $i++)
    {
        if($nhc->[$i] == $new_coordinator)
        {
            $found = 1;
            splice(@{$nhc}, $i, 1);
            last;
        }
    }
    if(!$found)
    {
        log_fatal("Could not find the phrase among my non-core children");
    }
    # Add it to my coordinators.
    my $cnj = $self->_coordinators_ref();
    push(@{$cnj}, $new_coordinator);
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
    log_fatal('Dead') if($self->dead());
    my @punctuation = @{$self->_punctuation_ref()};
    return $self->_order_required(@_) ? $self->order_phrases(@punctuation) : @punctuation;
}



#------------------------------------------------------------------------------
# Adds a phrase as a new punctuation delimiter to this coordination. The phrase
# may be currently a dependent of another phrase and will be correctly
# re-linked. However, it must not be a core child of any phrase.
#------------------------------------------------------------------------------
sub add_punctuation
{
    log_fatal('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $new_punctuation = shift;
    log_fatal('Dead') if($self->dead());
    # First make it my dependent. This ensures that the new phrase is
    # correctly detached from its current parent, if any. If it is already my
    # dependent, nothing will happen. But if it is my or someone else's core
    # child, an exception will be thrown. The set_parent() method also checks
    # that no cycle will be created.
    $new_punctuation->set_parent($self);
    # Now remove it from my dependents and add it to my coordinators.
    my $nhc = $self->_dependents_ref();
    my $found = 0;
    for(my $i = 0; $i <= $#{$nhc}; $i++)
    {
        if($nhc->[$i] == $new_punctuation)
        {
            $found = 1;
            splice(@{$nhc}, $i, 1);
            last;
        }
    }
    if(!$found)
    {
        log_fatal("Could not find the phrase among my non-core children");
    }
    # Add it to my coordinators.
    my $cnj = $self->_punctuation_ref();
    push(@{$cnj}, $new_punctuation);
}



#------------------------------------------------------------------------------
# Returns the head child of the phrase. Depending on the current preference,
# it is either the preposition or its argument.
#------------------------------------------------------------------------------
sub head
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
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
        log_fatal("Unknown head rule '$rule'");
    }
}



#------------------------------------------------------------------------------
# Returns the list of non-head children of the phrase, i.e. the dependents plus
# all core children except the one that currently serves as the head.
#------------------------------------------------------------------------------
sub nonhead_children
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    my $head = $self->head();
    my @children = grep {$_ != $head} ($self->children());
    return $self->_order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the list of the children of the phrase that are not dependents, i.e.
# all conjuncts, coordinators and punctuation.
#------------------------------------------------------------------------------
sub core_children
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    my @children = ($self->conjuncts(), $self->coordinators(), $self->punctuation());
    return $self->_order_required(@_) ? $self->order_phrases(@children) : @children;
}



#------------------------------------------------------------------------------
# Returns the type of the dependency relation of the coordination to its
# governing phrase.
#------------------------------------------------------------------------------
sub deprel
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    my @conjuncts = $self->conjuncts();
    return $conjuncts[0]->deprel();
}



#------------------------------------------------------------------------------
# Sets a new type of the dependency relation of the coordination to its
# governing phrase. For nonterminal phrases the label is propagated to one (or
# several) of their children. It is not propagated to the underlying dependency
# tree (the project_dependencies() method would have to be called to achieve
# that).
#------------------------------------------------------------------------------
sub set_deprel
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    my @conjuncts = $self->conjuncts('ordered' => 1);
    if($self->head_rule() eq 'last_coordinator')
    {
        ###!!! Orphans from elided conjuncts are labeled 'ExD' in the Prague
        ###!!! annotation style. This is the only legitimate case when a non-first
        ###!!! "conjunct" has not the same deprel as the first conjunct.
        my $exd_means_orphan = $conjuncts[0]->deprel() ne 'ExD';
        foreach my $c (@conjuncts)
        {
            unless($exd_means_orphan && $c->deprel() eq 'ExD')
            {
                $c->set_deprel(@_);
            }
        }
    }
    else # head_rule eq 'first_conjunct'
    {
        $self->head()->set_deprel(@_);
    }
}



#------------------------------------------------------------------------------
# Returns the deprel that should be used when the phrase tree is projected back
# to a dependency tree (see the method project_dependencies()). In most cases
# this is identical to what deprel() returns. However, for instance
# coordinations in Prague treebanks are attached using Coord. Their
# relation to the parent (returned by deprel()) is projected to the conjuncts.
#------------------------------------------------------------------------------
sub project_deprel
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    if($self->head_rule() eq 'last_coordinator')
    {
        return 'Coord'; ###!!! attribute / dialect?
    }
    else
    {
        return $self->head()->project_deprel();
    }
}



#------------------------------------------------------------------------------
# Replaces one of the core children (conjunct, coordinator or punctuation) by
# another phrase. This is used when we want to transform the child to a
# different class of phrase. The replacement must not have a parent yet.
#------------------------------------------------------------------------------
sub replace_core_child
{
    my $self = shift;
    my $old_child = shift; # Treex::Core::Phrase
    my $new_child = shift; # Treex::Core::Phrase
    log_fatal('Dead') if($self->dead());
    $self->_check_old_new_child($old_child, $new_child);
    $old_child->_set_parent(undef);
    $new_child->_set_parent($self);
    # Find out what type of core child this is (in which array we have it).
    my $ar = $self->_conjuncts_ref();
    my $imax = $#{$ar};
    for(my $i = 0; $i <= $imax; $i++)
    {
        if($ar->[$i] == $old_child)
        {
            splice(@{$ar}, $i, 1, $new_child);
            return;
        }
    }
    # Not found among conjuncts. Try coordinators.
    $ar = $self->_coordinators_ref();
    $imax = $#{$ar};
    for(my $i = 0; $i <= $imax; $i++)
    {
        if($ar->[$i] == $old_child)
        {
            splice(@{$ar}, $i, 1, $new_child);
            return;
        }
    }
    # Not found among coordinators. Try punctuation.
    $ar = $self->_punctuation_ref();
    $imax = $#{$ar};
    for(my $i = 0; $i <= $imax; $i++)
    {
        if($ar->[$i] == $old_child)
        {
            splice(@{$ar}, $i, 1, $new_child);
            return;
        }
    }
    # We should not ever get here.
    log_fatal("The child to be replaced is not in my core");
}



#------------------------------------------------------------------------------
# Projects dependencies between the head and the dependents back to the
# underlying dependency structure.
#------------------------------------------------------------------------------
sub project_dependencies
{
    my $self = shift;
    log_fatal('Dead') if($self->dead());
    my $head_rule = $self->head_rule();
    my @conjuncts = $self->conjuncts('ordered' => 1);
    my @coordinators = $self->coordinators('ordered' => 1);
    my @punctuation = $self->punctuation('ordered' => 1);
    my @dependents = $self->dependents();
    if($head_rule eq 'last_coordinator' && scalar(@coordinators) == 0 && scalar(@punctuation) == 0)
    {
        log_warn("Coordination without delimiters cannot use the 'last_coordinator' head rule.");
        $head_rule = 'first_conjunct'; ###!!! But then it should be possible to define deprels for this head rule in the current dialect.
    }
    # Recursion first, we work bottom-up.
    my @children = $self->children();
    foreach my $child (@children)
    {
        $child->project_dependencies();
    }
    my $head_node = $self->node();
    # We also have to change selected deprels. It depends on the current head rule.
    if($head_rule eq 'first_conjunct')
    {
        # If the first conjunct has a deprel other than 'dep', and another conjunct has 'dep',
        # then the other conjunct is an orphan caused by ellipsis. We currently keep the 'dep'
        # relation for orphans and do not label them 'conj'.
        ###!!! This is specific to the conversion from the Prague style to Universal Dependencies.
        ###!!! It should be solved elsewhere. Even orphans are not the main business of coordinations.
        my $dep_means_orphan = $self->deprel() ne 'dep';
        shift(@conjuncts);
        foreach my $c (@conjuncts)
        {
            my $conj_node = $c->node();
            $conj_node->set_parent($head_node);
            ###!!! The old implementation of Udep did not care about the ExD orphans.
            ###!!! Thus we will turn this off at least until we successfully pass regression tests
            ###!!! and fully deploy the new implementation.
            if(0 && ###!!!
               $dep_means_orphan && $c->deprel() eq 'dep')
            {
                $conj_node->set_deprel('dep');
            }
            else
            {
                $conj_node->set_deprel('conj');
            }
        }
        foreach my $c (@coordinators)
        {
            my $coor_node = $c->node();
            $coor_node->set_parent($head_node);
            $coor_node->set_deprel('cc');
        }
        foreach my $p (@punctuation)
        {
            my $punct_node = $p->node();
            $punct_node->set_parent($head_node);
            $punct_node->set_deprel('punct');
        }
        foreach my $d (@dependents)
        {
            my $dep_node = $d->node();
            $dep_node->set_parent($head_node);
            $dep_node->set_deprel($d->project_deprel());
        }
    }
    elsif($head_rule eq 'last_coordinator')
    {
        my $head = scalar(@coordinators) > 0 ? pop(@coordinators) : pop(@punctuation);
        $head->set_deprel('Coord');
        $head_node = $head->node();
        foreach my $c (@conjuncts)
        {
            my $conj_node = $c->node();
            $conj_node->set_parent($head_node);
            $conj_node->set_deprel($c->project_deprel());
            $conj_node->set_is_member(1);
        }
        foreach my $c (@coordinators)
        {
            my $coor_node = $c->node();
            $coor_node->set_parent($head_node);
            $coor_node->set_deprel('AuxY');
        }
        foreach my $p (@punctuation)
        {
            my $punct_node = $p->node();
            $punct_node->set_parent($head_node);
            $punct_node->set_deprel($punct_node->form() eq ',' ? 'AuxX' : 'AuxG');
        }
        foreach my $d (@dependents)
        {
            my $dep_node = $d->node();
            $dep_node->set_parent($head_node);
            $dep_node->set_deprel($d->project_deprel());
        }
    }
    else
    {
        log_fatal("Unknown coordination head rule '$head_rule'.");
    }
}



#------------------------------------------------------------------------------
# Returns a textual representation of the phrase and all subphrases. Useful for
# debugging.
#------------------------------------------------------------------------------
sub as_string
{
    my $self = shift;
    my @conjuncts = $self->conjuncts('ordered' => 1);
    my $conj = 'CONJ '.join(', ', map {$_->as_string()} (@conjuncts));
    my @coordinators = $self->coordinators('ordered' => 1);
    my $coor = join(', ', map {$_->as_string()} (@coordinators));
    $coor = 'COOR '.$coor if($coor);
    my @punctuation = $self->punctuation('ordered' => 1);
    my $punc = join(', ', map {$_->as_string()} (@punctuation));
    $punc = 'PUNC '.$punc if($punc);
    my @dependents = $self->dependents('ordered' => 1);
    my $deps = join(', ', map {$_->as_string()} (@dependents));
    $deps = 'DEPS '.$deps if($deps);
    my $subtree = join(' ', ($conj, $coor, $punc, $deps));
    return "(CO $subtree)";
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::Coordination

=head1 SYNOPSIS

  use Treex::Core::Document;
  use Treex::Core::Phrase::Term;
  use Treex::Core::Phrase::Coordination;

  my $document = new Treex::Core::Document;
  my $bundle   = $document->create_bundle();
  my $zone     = $bundle->create_zone('en');
  my $root     = $zone->create_atree();
  my $coord    = $root->create_child();
  my $conj1    = $coord->create_child();
  my $conj2    = $coord->create_child();
  $coord->set_deprel('Coord');
  $conj1->set_deprel('Pred_M');
  $conj2->set_deprel('Pred_M');
  my $coordphr = new Treex::Core::Phrase::Term ('node' => $coord);
  my $conj1phr = new Treex::Core::Phrase::Term ('node' => $conj1);
  my $conj2phr = new Treex::Core::Phrase::Term ('node' => $conj2);
  my $cphrase  = new Treex::Core::Phrase::Coordination ('conjuncts' => [$conj1phr, $conj2phr], 'coordinators' => [$coordphr], 'head_rule' => 'last_coordinator');

=head1 DESCRIPTION

C<Treex::Core::Phrase::Coordination> is a special case of
C<Treex::Core::Phrase::NTerm>. It does not have a fixed head but it has a head
rule that specifies how the head child should be determined if needed. On the
other hand, there are several sets of core children that are not ordinary
dependents. They are conjuncts (i.e. the phrases that are coordinated),
coordinators (coordinating conjunctions and similar words) and
conjunct-delimiting punctuation.

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

=item add_conjunct

Adds a phrase as a new conjunct to this coordination. The phrase may be
currently a dependent of another phrase and will be correctly re-linked.
However, it must not be a core child of any phrase.

=item coordinators

Returns the list of coordinating conjunctions (but not punctuation).
The only difference from the
getter C<_coordinators_ref()> is that the getter returns a reference to array,
while this method returns a list. Hence this method is
more similar to the other methods that return lists of children.

=item add_coordinator

Adds a phrase as a new coordinator to this coordination. The phrase may be
currently a dependent of another phrase and will be correctly re-linked.
However, it must not be a core child of any phrase.

=item punctuation

Returns the list of punctuation symbols between conjuncts.
The only difference from the
getter C<_punctuation_ref()> is that the getter returns a reference to array,
while this method returns a list. Hence this method is
more similar to the other methods that return lists of children.

=item add_punctuation

Adds a phrase as a new punctuation delimiter to this coordination. The phrase
may be currently a dependent of another phrase and will be correctly
re-linked. However, it must not be a core child of any phrase.

=item nonhead_children

Returns the list of non-head children of the phrase, i.e. the dependents plus
all core children except the one that currently serves as the head.

=item core_children

Returns the list of the children of the phrase that are not dependents, i.e.
all conjuncts, coordinators and punctuation.

=item deprel

Returns the type of the dependency relation of the coordination to the governing
phrase.

=item set_deprel

Sets a new type of the dependency relation of the phrase to the governing
phrase. For nonterminal phrases the label is propagated to one (or several)
of their children. It is not propagated to the underlying dependency tree
(the C<project_dependencies()> method would have to be called to achieve that).

Depending on the current annotation style, deprel of coordination is propagated
either to just the first conjunct, or to all conjuncts (except for orphans from
elided conjuncts).

=item project_deprel

Returns the deprel that should be used when the phrase tree is projected back
to a dependency tree (see the method project_dependencies()). In most cases
this is identical to what deprel() returns. However, for instance
coordinations in Prague treebanks are attached using C<Coord>. Their
relation to the parent (returned by deprel()) is projected to the conjuncts.

=item project_dependencies

Projects dependencies between the head and the dependents back to the
underlying dependency structure.
For coordinations the behavior depends on the currently selected head rule:
certain deprels may have to be adjusted.

=item as_string

Returns a textual representation of the phrase and all subphrases. Useful for
debugging.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
