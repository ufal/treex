package Treex::Core::Phrase::Builder;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Phrase::Term;
use Treex::Core::Phrase::NTerm;
use Treex::Core::Phrase::PP;
use Treex::Core::Phrase::Coordination;



has 'prep_is_head' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 0,
    documentation =>
        'See Treex::Core::Phrase::PP, prep_is_head attribute.'
);

has 'coordination_head_rule' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'first_conjunct',
    documentation =>
        'See Treex::Core::Phrase::Coordination, head_rule attribute.'
);



#------------------------------------------------------------------------------
# Wraps a node (and its subtree, if any) in a phrase.
#------------------------------------------------------------------------------
sub build
{
    my $self = shift;
    my $node = shift; # Treex::Core::Node
    my @nchildren = $node->children();
    my $phrase = new Treex::Core::Phrase::Term('node' => $node);
    if(@nchildren)
    {
        # Create a new nonterminal phrase and make the current terminal phrase its head child.
        $phrase = new Treex::Core::Phrase::NTerm('head' => $phrase);
        foreach my $nchild (@nchildren)
        {
            my $pchild = $self->build($nchild);
            $pchild->set_parent($phrase);
        }
        # The following is the only part (so far) that assumes one particular
        # annotation style. In future we will want to parameterize the Builder
        # by properties of the expected input style.
        $phrase = $self->detect_prague_pp($phrase);
        $phrase = $self->detect_prague_coordination($phrase);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style (with analytical functions
# converted to dependency relation labels based on Universal Dependencies).
# If it recognizes a prepositional phrase, transforms the general NTerm to PP.
# A subordinate clause headed by AuxC is also treated as PP.
#------------------------------------------------------------------------------
sub detect_prague_pp
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    # If this is the Prague style then the preposition (if any) must be the head.
    # The deprel is already partially converted to UD, so it should be something:auxp
    # (case:auxp, mark:auxp, root:auxp); see HamleDT::Udep->afun_to_udeprel().
    if($phrase->deprel() =~ m/aux[pc]/i)
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        my @mwauxp;
        my @punc;
        my @candidates;
        # Classify dependents of the preposition.
        foreach my $d (@dependents)
        {
            # AuxP attached to AuxP means multi-word preposition.
            # The dependent should be a leaf, otherwise we may have a recursive structure.
            # But we are working bottom-up. If there is a recursive AuxP-AuxP-arg structure, the inner part has already been processed and its head deprel is no longer AuxP.
            ###!!! We should also check that all words of a MWE are adjacent!
            if($d->deprel() =~ m/aux[pc]/i)
            {
                push(@mwauxp, $d);
            }
            # Punctuation should never represent an argument of a preposition (provided we have solved any coordinations on lower levels).
            elsif($d->node()->is_punctuation())
            {
                push(@punc, $d);
            }
            # All other dependents are candidates for the argument.
            else
            {
                push(@candidates, $d);
            }
        }
        # If there are no argument candidates, we cannot create a prepositional phrase.
        my $n = scalar(@candidates);
        if($n == 0)
        {
            return $phrase;
        }
        # Now it is clear that we have a prepositional phrase. A new PP will be created
        # and the old input NTerm will be destroyed.
        my $preposition = $phrase->head();
        $preposition->set_deprel('case'); ###!!! TODO: sometimes it will be mark. And sometimes we need the whole thing to become root, but it will not be stored at the preposition.
        # If there are two or more argument candidates, we have to select the best one.
        # There may be more sophisticated approaches but let's just take the first one for the moment.
        ###!!! This should work reasonably well for languages that have mostly prepositions.
        ###!!! If we know that there are mostly postpositions, we may prefer to take the last candidate.
        my $argument = shift(@candidates);
        my $parent = $phrase->parent();
        $phrase->detach_children_and_die();
        # If the preposition consists of multiple nodes, group them in a new NTerm first.
        # The main prepositional node has already been detached from its original parent so it can be used as the head elsewhere.
        if(scalar(@mwauxp) > 0)
        {
           $preposition = new Treex::Core::Phrase::NTerm('head' => $preposition);
           foreach my $mwp (@mwauxp)
           {
               $mwp->set_parent($preposition);
           }
        }
        my $pp = new Treex::Core::Phrase::PP
        (
            'prep'           => $preposition,
            'arg'            => $argument,
            'prep_is_head'   => $self->prep_is_head(),
            'deprel_at_prep' => 0
        );
        foreach my $d (@candidates, @punc)
        {
            $d->set_parent($pp);
        }
        # If the original phrase already had a parent, we must make sure that
        # the parent is aware of the reincarnation we have made.
        if(defined($parent))
        {
            $parent->replace_child($phrase, $pp);
        }
        return $pp;
    }
    # Return the input NTerm phrase if no PP has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style (with analytical functions
# converted to dependency relation labels based on Universal Dependencies). If
# it recognizes a coordination, transforms the general NTerm to Coordination.
#------------------------------------------------------------------------------
sub detect_prague_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    # If this is the Prague style then the head is either coordinating conjunction or punctuation.
    # The deprel is already partially converted to UD, so it should be something:coord
    # (cc:coord, punct:coord, root:coord); see HamleDT::Udep->afun_to_udeprel().
    if($phrase->deprel() =~ m/coord/i)
    {
        # If the whole coordination must have the deprel root because it is
        # attached to the root node, it has now the deprel 'root:coord'.
        # Remember that we must modify the head deprel later.
        ###!!! Coordination should not have to care about this! It would be
        ###!!! better to define a new special type of nonterminal phrase,
        ###!!! Phrase::Root. It would have one core child (head) but it would
        ###!!! always give the child the deprel root. And in the UD style it
        ###!!! might also ensure that there is only one root child and no
        ###!!! dependents.
        my $root_deprel_override = $phrase->deprel() =~ m/^root/i;
        my @dependents = $phrase->dependents('ordered' => 1);
        my @conjuncts;
        my @coordinators;
        my @punctuation;
        my @sdependents;
        # Classify dependents.
        my ($cmin, $cmax);
        foreach my $d (@dependents)
        {
            # Elsewhere in Treex the Prague-style trees use afuns instead of
            # deprels, and conjuncts have an additional attribute is_member.
            # We try to make everything less Prague-dependent and work only
            # with deprel, with no constraints put on the deprel values. Here
            # we assume that both afun and is_member have been combined in
            # deprel; is_member marked by a ':member' suffix.
            if($d->deprel() =~ m/:member$/)
            {
                push(@conjuncts, $d);
                $cmin = $d->ord() if(!defined($cmin));
                $cmax = $d->ord();
            }
            # Additional coordinating conjunctions (except the head) are not
            # labeled by a dedicated deprel. They are labeled AuxY but other
            # words in the tree may get this label too.
            elsif($d->deprel() eq 'AuxY')
            {
                push(@coordinators, $d);
            }
            # Punctuation is attached as AuxX (commas) or AuxG (everything
            # else). We will ignore punctuation labeled Coord or Appos because
            # it heads a nested coordination or apposition, hence it is either
            # a conjunct (Coord_M, Appos_M) or a shared dependent (without _M).
            elsif($d->deprel() =~ m/^Aux[XG]$/)
            {
                push(@punctuation, $d);
            }
            # The rest are dependents shared by all the conjuncts.
            else
            {
                push(@sdependents, $d);
            }
        }
        # Punctuation can be considered a conjunct delimiter only if it occurs
        # between conjuncts.
        my @inpunct  = grep {my $o = $_->ord(); $o > $cmin && $o < $cmax;} (@punctuation);
        my @outpunct = grep {my $o = $_->ord(); $o < $cmin || $o > $cmax;} (@punctuation);
        # If there are no conjuncts, we cannot create a coordination.
        my $n = scalar(@conjuncts);
        if($n == 0)
        {
            return $phrase;
        }
        # Now it is clear that we have a coordination. A new Coordination phrase will be created
        # and the old input NTerm will be destroyed.
        my $parent = $phrase->parent();
        my $old_head = $phrase->head();
        $phrase->detach_children_and_die();
        push(@coordinators, $old_head);
        my $coordination = new Treex::Core::Phrase::Coordination
        (
            'conjuncts' => \@conjuncts,
            'coordinators' => \@coordinators,
            'punctuation' => \@inpunct,
            'head_rule' => $self->coordination_head_rule()
        );
        # If the whole coordination shall have the deprel 'root', assign it now
        # to the head child.
        if($root_deprel_override)
        {
            $coordination->set_deprel('root');
        }
        # Remove the ':member' part from the deprels of the conjuncts. Keep the
        # main deprels as these may not necessarily be the same for all conjuncts.
        # Do not assign 'conj' as the deprel of the non-head conjuncts. That will
        # be set during back-projection to the dependency tree, based on the
        # annotation style that will be selected at that time.
        foreach my $c (@conjuncts)
        {
            my $deprel = $c->deprel();
            $deprel =~ s/:member$//;
            $c->set_deprel($deprel);
        }
        foreach my $d (@sdependents, @outpunct)
        {
            $d->set_parent($coordination);
        }
        # If the original phrase already had a parent, we must make sure that
        # the parent is aware of the reincarnation we have made.
        if(defined($parent))
        {
            $parent->replace_child($phrase, $coordination);
        }
        return $coordination;
    }
    # Return the input NTerm phrase if no Coordination has been detected.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::Builder

=head1 DESCRIPTION

A C<Builder> provides methods to construct a phrase structure tree around
a dependency tree. It takes a C<Node> and returns a C<Phrase>.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=item detect_prague_pp

Examines a nonterminal phrase in the Prague style. If it recognizes
a prepositional phrase, transforms the general nonterminal to PP.
Returns the resulting phrase (if nothing has been changed, returns
the original phrase).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
