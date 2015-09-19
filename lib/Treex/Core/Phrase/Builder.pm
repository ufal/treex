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
        'Should preposition and subordinating conjunction head its phrase? '.
        'See Treex::Core::Phrase::PP, fun_is_head attribute.'
);

has 'cop_is_head' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 0,
    documentation =>
        'Should copula head its phrase? '.
        'See Treex::Core::Phrase::PP, fun_is_head attribute.'
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
        # Move the is_member flag to the parent phrase.
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Create a new nonterminal phrase and make the current terminal phrase its head child.
        $phrase = new Treex::Core::Phrase::NTerm('head' => $phrase, 'is_member' => $member);
        foreach my $nchild (@nchildren)
        {
            my $pchild = $self->build($nchild);
            $pchild->set_parent($phrase);
        }
        # The following is the only part (so far) that assumes one particular
        # annotation style. In future we will want to parameterize the Builder
        # by properties of the expected input style.
        $phrase = $self->detect_prague_pp($phrase);
        $phrase = $self->detect_prague_copula($phrase);
        $phrase = $self->detect_prague_coordination($phrase);
        $phrase = $self->detect_colon_predicate($phrase);
        $phrase = $self->detect_root_phrase($phrase);
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
    # (case:auxp, mark:auxp); see HamleDT::Udep->afun_to_udeprel().
    if($phrase->deprel() =~ m/^(case|mark):(aux[pc])/i)
    {
        my $target_deprel = $1;
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
        $preposition->set_deprel($target_deprel);
        # If there are two or more argument candidates, we have to select the best one.
        # There may be more sophisticated approaches but let's just take the first one for the moment.
        ###!!! This should work reasonably well for languages that have mostly prepositions.
        ###!!! If we know that there are mostly postpositions, we may prefer to take the last candidate.
        # Emphasizers (AuxZ or advmod:emph) preceding the preposition should be
        # attached to the argument rather than the preposition. However,
        # occasionally they are attached to the preposition, as in [cs]:
        #   , přinejmenším pokud jde o platy
        #   , at-least if are-concerned about salaries
        # ("pokud" is the AuxC and the original head, "přinejmenším" should be
        # attached to the verb "jde" but it is attached to "pokud", thus
        # "pokud" has two children. We want the verb "jde" to become the
        # argument.)
        # Similarly [cs]:
        #   třeba v tom
        #   for-example in the-fact
        # In this case, "třeba" is attached to "v" as AuxY (cc), not as AuxZ (advmod:emph).
        my @ecandidates = grep {$_->deprel() =~ m/^(advmod:emph|cc)$/} (@candidates);
        my @ocandidates = grep {$_->deprel() !~ m/^(advmod:emph|cc)$/} (@candidates);
        my $argument;
        if(scalar(@ocandidates)>0)
        {
            $argument = shift(@ocandidates);
            @candidates = (@ecandidates, @ocandidates);
        }
        else
        {
            $argument = shift(@candidates);
        }
        my $parent = $phrase->parent();
        my $member = $phrase->is_member();
        $phrase->detach_children_and_die();
        # If the preposition consists of multiple nodes, group them in a new NTerm first.
        # The main prepositional node has already been detached from its original parent so it can be used as the head elsewhere.
        if(scalar(@mwauxp) > 0)
        {
            # The leftmost node of the MWE will be its head.
            @mwauxp = sort {$a->node()->ord() <=> $b->node()->ord()} (@mwauxp, $preposition);
            my $prepdeprel = $preposition->deprel();
            $preposition = new Treex::Core::Phrase::NTerm('head' => shift(@mwauxp));
            $preposition->set_deprel($prepdeprel);
            foreach my $mwp (@mwauxp)
            {
                $mwp->set_parent($preposition);
                $mwp->set_deprel('mwe');
            }
        }
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $preposition,
            'arg'           => $argument,
            'fun_is_head'   => $self->prep_is_head(),
            'deprel_at_fun' => 0,
            'is_member'     => $member
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
# converted to dependency relation labels based on Universal Dependencies).
# If it recognizes a copula construction, transforms the general NTerm to PP.
#------------------------------------------------------------------------------
sub detect_prague_copula
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    # If this is the Prague style then the copula (if any) must be the head.
    # The deprel is already partially converted to UD, so there should be a child
    # labeled dep:pnom; see HamleDT::Udep->afun_to_udeprel().
    my @pnom = grep {$_->deprel() =~ m/pnom/i} ($phrase->dependents('ordered' => 1));
    if(scalar(@pnom)>=1)
    {
        # Now it is clear that we have a nominal predicate with copula.
        # A new PP will be created and the old input NTerm will be destroyed.
        my $copula = $phrase->head();
        # There should not be more than one nominal predicate but it is not guaranteed.
        # It is not clear what to do in such cases; we will pick the first one.
        # Note that the nominal predicate can also be seen as the argument of the copula,
        # and we will denote it as $argument here, which is the terminology inside Phrase::PP.
        my $argument = shift(@pnom);
        my @dependents = grep {$_ != $copula && $_ != $argument} ($phrase->children());
        my $parent = $phrase->parent();
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->detach_children_and_die();
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $copula,
            'arg'           => $argument,
            'fun_is_head'   => $self->cop_is_head(),
            'deprel_at_fun' => 0,
            'is_member'     => $member
        );
        $copula->set_deprel('cop');
        $pp->set_deprel($deprel);
        foreach my $d (@dependents)
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
    # (cc:coord, punct:coord); see HamleDT::Udep->afun_to_udeprel().
    if($phrase->deprel() =~ m/:coord/i)
    {
        # Remove the ':coord' part from the deprel. Even if we do not find any
        # conjunct and cannot construct coordination, the label cannot remain
        # in the data.
        my $deprel = $phrase->deprel();
        $deprel =~ s/:coord//i;
        $phrase->set_deprel($deprel);
        my @dependents = $phrase->dependents('ordered' => 1);
        my @conjuncts;
        my @coordinators;
        my @punctuation;
        my @sdependents;
        # Classify dependents.
        my ($cmin, $cmax);
        foreach my $d (@dependents)
        {
            if($d->is_member())
            {
                push(@conjuncts, $d);
                $cmin = $d->ord() if(!defined($cmin));
                $cmax = $d->ord();
            }
            # Additional coordinating conjunctions (except the head).
            # In PDT they are labeled AuxY but other words in the tree may get
            # this label too. During label conversion it is converted to cc.
            elsif($d->deprel() eq 'cc')
            {
                push(@coordinators, $d);
            }
            # Punctuation (except the head).
            # In PDT it is labeled AuxX (commas) or AuxG (everything else).
            # During label conversion both are converted to punct.
            # Some punctuation may have headed a nested coordination or
            # apposition (playing either a conjunct or a shared dependent) but
            # it should have been processed by now, as we are proceeding
            # bottom-up.
            elsif($d->deprel() eq 'punct')
            {
                push(@punctuation, $d);
            }
            # The rest are dependents shared by all the conjuncts.
            else
            {
                push(@sdependents, $d);
            }
        }
        # If there are no conjuncts, we cannot create a coordination.
        my $n = scalar(@conjuncts);
        if($n == 0)
        {
            return $phrase;
        }
        # Now it is clear that we have a coordination. A new Coordination phrase will be created
        # and the old input NTerm will be destroyed.
        my $parent = $phrase->parent();
        my $member = $phrase->is_member();
        my $old_head = $phrase->head();
        $phrase->detach_children_and_die();
        if($deprel eq 'punct')
        {
            push(@punctuation, $old_head);
        }
        else
        {
            push(@coordinators, $old_head);
        }
        # Punctuation can be considered a conjunct delimiter only if it occurs
        # between conjuncts.
        my @inpunct  = grep {my $o = $_->ord(); $o > $cmin && $o < $cmax;} (@punctuation);
        my @outpunct = grep {my $o = $_->ord(); $o < $cmin || $o > $cmax;} (@punctuation);
        my $coordination = new Treex::Core::Phrase::Coordination
        (
            'conjuncts'    => \@conjuncts,
            'coordinators' => \@coordinators,
            'punctuation'  => \@inpunct,
            'head_rule'    => $self->coordination_head_rule(),
            'is_member'    => $member
        );
        # Remove the is_member flag from the conjuncts. It will be no longer
        # needed as we now know what are the conjuncts.
        # Do not assign 'conj' as the deprel of the non-head conjuncts. That will
        # be set during back-projection to the dependency tree, based on the
        # annotation style that will be selected at that time.
        foreach my $c (@conjuncts)
        {
            $c->set_is_member(0);
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



#------------------------------------------------------------------------------
# The colon is sometimes treated as a substitute for the main predicate in the
# PDT (usually the hypothetical predicate would equal to "is").
# Example: "Veletrh GOLF 94 München: 2. – 4. 9." ("GOLF 94 fair Munich:
# September 2 – 9")
# We will make the first part the main constituent, and attach the second part
# as apposition. In some cases the colon is analyzed as copula (and the second
# part is a nominal predicate) so we want to do this before copulas are
# processed. Otherwise the scene will be reshaped and we will not recognize it.
#------------------------------------------------------------------------------
sub detect_colon_predicate
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    my $deprel = $phrase->deprel();
    my $node = $phrase->node();
    ###!!! Should we test that we are dealing with Phrase::NTerm and not e.g. with Phrase::Coordination?
    if(defined($node->parent()) && $node->parent()->is_root() && $node->form() eq ':')
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        # Make the first child of the colon the new top node.
        # We want a non-punctuation child. If there are only punctuation children, do not do anything.
        my @npunct = grep {!$_->node()->is_punctuation()} (@dependents);
        my @punct  = grep { $_->node()->is_punctuation()} (@dependents);
        if(scalar(@npunct)>=1)
        {
            my $old_head = $phrase->head();
            my $new_head = shift(@npunct);
            $phrase->set_head($new_head);
            $phrase->set_deprel($deprel);
            $old_head->set_deprel('punct');
            # All other children of the colon (if any; probably just one other child) will be attached to the new head as apposition.
            foreach my $d (@npunct)
            {
                $d->set_deprel('appos');
            }
        }
    }
    # Return the modified phrase as with all detect methods.
    return $phrase;
}



#------------------------------------------------------------------------------
# Checks whether the head node of a phrase is the artificial root of the
# dependency tree. If so, then it makes sure that there is only one dependent
# and its deprel is "root" (there is a consensus in Universal Dependencies that
# there should be always just one node attached to the artificial root and
# labeled "root"). If there were multiple dependents, the leftmost will be kept
# and the others will be made its dependents (and grandchildren of the
# artificial root node).
#------------------------------------------------------------------------------
sub detect_root_phrase
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    if($phrase->node()->is_root())
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        # The artificial root node cannot have more than one child.
        if(scalar(@dependents)>1)
        {
            # Avoid punctuation as the head if possible.
            my @punct = grep {$_->node()->is_punctuation()} (@dependents);
            my @npunct = grep {!$_->node()->is_punctuation()} (@dependents);
            my $leftmost;
            if(@npunct)
            {
                $leftmost = shift(@npunct);
                @dependents = (@npunct, @punct);
            }
            else
            {
                $leftmost = shift(@dependents);
            }
            $leftmost->set_parent(undef);
            # Create a new nonterminal phrase with the leftmost dependent as head and the others as dependents.
            my $subphrase = new Treex::Core::Phrase::NTerm('head' => $leftmost);
            foreach my $d (@dependents)
            {
                $d->set_parent($subphrase);
                # Solve the sentence-final punctuation at the same time.
                if($d->deprel() eq 'root:auxk')
                {
                    $d->set_deprel('punct');
                }
            }
            $subphrase->set_parent($phrase);
            @dependents = ($subphrase);
        }
        # The child of the artificial root node is always attached with the label "root".
        if(scalar(@dependents)>0)
        {
            $dependents[0]->set_deprel('root');
        }
    }
    # Return the modified phrase as with all detect methods.
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

=item detect_prague_coordination

Examines a nonterminal phrase in the Prague style (with analytical functions
converted to dependency relation labels based on Universal Dependencies). If
it recognizes a coordination, transforms the general NTerm to Coordination.

=item detect_colon_predicate

The colon is sometimes treated as a substitute for the main predicate in PDT
(usually the hypothetical predicate would equal to I<is>).

Example:
I<Veletrh GOLF 94 München: 2. – 4. 9.>
(“GOLF 94 fair Munich: September 2 – 9”)

We will make the first part the main constituent, and attach the second part
as apposition. In some cases the colon is analyzed as copula (and the second
part is a nominal predicate) so we want to do this before copulas are
processed. Otherwise the scene will be reshaped and we will not recognize it.

=item detect_root_phrase

Checks whether the head node of a phrase is the artificial root of the
dependency tree. If so, then it makes sure that there is only one dependent
and its deprel is "root" (there is a consensus in Universal Dependencies that
there should be always just one node attached to the artificial root and
labeled "root"). If there were multiple dependents, the leftmost will be kept
and the others will be made its dependents (and grandchildren of the
artificial root node).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
