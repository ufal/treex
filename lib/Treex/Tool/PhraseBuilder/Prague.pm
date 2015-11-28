package Treex::Tool::PhraseBuilder::Prague;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Phrase::Term;
use Treex::Core::Phrase::NTerm;
use Treex::Core::Phrase::PP;
use Treex::Core::Phrase::Coordination;

extends 'Treex::Core::Phrase::Builder';



has 'prep_is_head' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
    documentation =>
        'Should preposition and subordinating conjunction head its phrase? '.
        'See Treex::Core::Phrase::PP, fun_is_head attribute.'
);

has 'coordination_head_rule' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'last_coordinator',
    documentation =>
        'See Treex::Core::Phrase::Coordination, head_rule attribute.'
);

has 'dialect' =>
(
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    documentation =>
        'Defines the dialect of the Prague annotation style: translates our '.
        '"neutral" labels to the dependency labels actually used in the data.'
);



#------------------------------------------------------------------------------
# Defines the dialect of the Prague annotation style that is used in the data.
# What dependency labels are used? By separating the labels from the other code
# we can use the same PhraseBuilder for Prague-style trees with original Prague
# labels (afuns), as well as for trees in which the labels have already been
# translated to Universal Dependencies (but the topology is still Prague-like).
#
# Usage 0: if ( $self->is_deprel( $deprel, 'punct' ) ) { ... }
# Usage 1: $self->set_deprel( $phrase, 'punct' );
#------------------------------------------------------------------------------
sub _build_dialect
{
    # A lazy builder can be called from anywhere, including map or grep. Protect $_!
    local $_;
    # Mapping from id to regular expression describing corresponding deprels in the dialect.
    # The second position is the label used in set_deprel(); not available for all ids.
    my %map =
    (
        'advmod'    => ['^Adv$', 'Adv'],
        'appos'     => ['^Apposition$', 'Apposition'],
        'aux'       => ['^AuxV$', 'AuxV'],
        'auxg'      => ['^AuxG$', 'AuxG'], # punctuation other than comma
        'auxk'      => ['^AuxK$', 'AuxK'], # sentence-terminating punctuation
        'auxpc'     => ['^Aux[PC]$'],
        'auxpc1'    => ['^Aux[PC]$'],
        'auxv'      => ['^AuxV$', 'AuxV'],
        'auxx'      => ['^AuxX$', 'AuxX'], # comma
        'auxy'      => ['^AuxY$', 'AuxY'], # additional coordinating conjunction or other function word
        'auxyz'     => ['^Aux[YZ]$'],
        'case'      => ['^AuxP$', 'AuxP'],
        'cc'        => ['^AuxY$', 'AuxY'],
        'ccomp'     => ['^Obj$', 'Obj'],
        'compound'  => ['^Compound$', 'Compound'],
        'coord'     => ['^Coord$'],
        'cop'       => ['^Cop$', 'Cop'],
        'cxcomp'    => ['^Obj$'],
        'dobj'      => ['^Obj$', 'Obj'],
        'iobj'      => ['^Obj$', 'Obj'],
        'mwe'       => ['^Mwe$', 'Mwe'],
        'name'      => ['^Name$', 'Name'],
        'nmod'      => ['^(Atr|Adv)$', 'Atr'],
        'nsubj'     => ['^Sb$', 'Sb'],
        'nummod'    => ['^Atr$'],
        'parataxis' => ['^Pred$', 'Pred'],
        'pnom'      => ['Pnom'],
        'punct'     => ['^Aux[XGK]$', 'AuxG'],
        'root'      => ['^Pred', 'Pred'],
        'subj'      => ['Sb'],
        'xcomp'     => ['^Obj$', 'Obj'],
    );
    return \%map;
}
sub is_deprel
{
    my $self = shift;
    my $deprel = shift; # deprel to test
    my $id = shift; # our neutral/mixed label
    my $map = $self->dialect();
    return exists($map->{$id}) && $deprel =~ m/$map->{$id}[0]/i;
}
sub set_deprel
{
    my $self = shift;
    my $phrase = shift;
    my $id = shift;
    my $map = $self->dialect();
    if(exists($map->{$id}) && defined($map->{$id}[1]))
    {
        return $phrase->set_deprel($map->{$id}[1]);
    }
    else
    {
        log_warn("Dependency relation '$id' is unknown in this dialect of phrase builder.");
        return $phrase->set_deprel("dep:$id");
    }
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase and tries to recognize certain special phrase
# types. This is the part of phrase building that is specific to expected input
# style and desired output style. This method is called from the core phrase
# building implemented in Treex::Core::Phrase::Builder, after a new nonterminal
# phrase is built.
#------------------------------------------------------------------------------
sub detect_special_constructions
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # The root node must not participate in any specialized construction.
    unless($phrase->node()->is_root())
    {
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree. For example: We see a phrase labeled Coord (coordination),
        # hence we do not see a prepositional phrase (the label would have to be AuxP
        # instead of Coord). However, after processing the coordination the phrase
        # will get a new label and it may well be AuxP.
        $phrase = $self->detect_prague_coordination($phrase);
        $phrase = $self->detect_prague_pp($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style. If it recognizes
# a coordination, transforms the general NTerm to Coordination.
###!!! The current implementation does not take into account possible orphans
###!!! caused by ellipsis.
#------------------------------------------------------------------------------
sub detect_prague_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the head is either coordinating conjunction or punctuation.
    if($self->is_deprel($phrase->deprel(), 'coord'))
    {
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
                # Occasionally punctuation is labeled as conjunct (not nested coordination,
                # which should be solved by now, but an orphan leaf node after ellipsis).
                # We want to make it normal punctuation instead.
                # (Note that we cannot recognize punctuation by dependency label in this case.
                # It will be labeled 'ExD', not 'AuxX' or 'AuxG'.)
                if($d->node()->is_punctuation() && $d->node()->is_leaf())
                {
                    $d->set_is_member(0);
                    push(@punctuation, $d);
                }
                else
                {
                    push(@conjuncts, $d);
                    $cmin = $d->ord() if(!defined($cmin));
                    $cmax = $d->ord();
                }
            }
            # Additional coordinating conjunctions (except the head).
            # In PDT they are labeled AuxY but other words in the tree may get
            # that label too. We identify it as 'cc' and use the dialect vocabulary
            # to see what label we actually expect.
            elsif($self->is_deprel($d->deprel(), 'cc'))
            {
                push(@coordinators, $d);
            }
            # Punctuation (except the head).
            # Some punctuation may have headed a nested coordination or
            # apposition (playing either a conjunct or a shared dependent) but
            # it should have been processed by now, as we are proceeding
            # bottom-up.
            elsif($self->is_deprel($d->deprel(), 'punct'))
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
            log_warn('Coordination without conjuncts');
            # We cannot keep 'coord' as the deprel of the phrase if there are no conjuncts.
            my $node = $phrase->node();
            my $deprel_id = defined($node->form()) && $node->form() eq ',' ? 'auxx' : $node->is_punctuation() ? 'auxg' : 'auxy';
            $self->set_deprel($phrase, $deprel_id);
            return $phrase;
        }
        # Now it is clear that we have a coordination. A new Coordination phrase will be created
        # and the old input NTerm will be destroyed.
        my $parent = $phrase->parent();
        my $member = $phrase->is_member();
        my $old_head = $phrase->head();
        $phrase->detach_children_and_die();
        # The dependency relation label of the coordination head was 'coord' regardless whether it was conjunction or punctuation.
        if($old_head->node()->is_punctuation())
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
        # needed as we now know what are the conjuncts. (It may be re-introduced
        # during back-projection to the dependency tree if the Prague annotation
        # style is retained. Similarly we do not change the deprel of the non-head
        # conjuncts now, but they may be later changed to 'conj' if the UD
        # annotation style is selected.)
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
# Examines a nonterminal phrase in the Prague style. If it recognizes
# a prepositional phrase, transforms the general NTerm to PP. A subordinate
# clause headed by AuxC is also treated as PP.
#------------------------------------------------------------------------------
sub detect_prague_pp
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the preposition (if any) must be the head.
    if($self->is_deprel($phrase->deprel(), 'auxpc'))
    {
        my $target_deprel = $phrase->deprel();
        my $c = $self->classify_prague_pp_subphrases($phrase);
        # If there are no argument candidates, we cannot create a prepositional phrase.
        if(!defined($c))
        {
            return $phrase;
        }
        # We are working bottom-up, thus the current phrase does not have a parent yet and we do not have to take care of the parent link.
        # We have to detach the argument though, and we have to port the is_member flag.
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Now it is clear that we have a prepositional phrase.
        # The preposition ($c->{fun}) is the current phrase but we have to detach the dependents and only keep the core.
        $c->{fun}->set_deprel($target_deprel);
        $c->{arg}->set_parent(undef);
        # If the preposition consists of multiple nodes, group them in a new NTerm first.
        # The main prepositional node has already been detached from its original parent so it can be used as the head elsewhere.
        if(scalar(@{$c->{mwe}}) > 0)
        {
            # The leftmost node of the MWE will be its head.
            my @mwe = sort {$a->node()->ord() <=> $b->node()->ord()} (@{$c->{mwe}}, $c->{fun});
            my $head = shift(@mwe);
            $head->set_parent(undef);
            $c->{fun} = new Treex::Core::Phrase::NTerm('head' => $head);
            $c->{fun}->set_deprel($target_deprel);
            foreach my $mwp (@mwe)
            {
                $mwp->set_parent($c->{fun});
                $self->set_deprel($mwp, 'mwe');
            }
        }
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $c->{fun},
            'arg'           => $c->{arg},
            'fun_is_head'   => $self->prep_is_head(),
            'deprel_at_fun' => 0,
            'is_member'     => $member
        );
        foreach my $d (@{$c->{dep}})
        {
            $d->set_parent($pp);
        }
        return $pp;
    }
    # Return the input NTerm phrase if no PP has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Takes a phrase that seems to be a prepositional phrase headed by the
# preposition. Classifies the children of the phrase: finds the preposition,
# the argument and the other dependents. Returns undef if it cannot find the
# argument: that means that this is not a PP! Otherwise returns a reference to
# a hash with preposition, argument and dependents. This method does not modify
# anything in the structure.
#------------------------------------------------------------------------------
sub classify_prague_pp_subphrases
{
    my $self = shift;
    my $phrase = shift; # the input phrase that seems to be a prepositional phrase headed by the preposition
    my @dependents = $phrase->dependents('ordered' => 1);
    my @mwauxp;
    my @punc;
    my @candidates;
    # Classify dependents of the preposition.
    foreach my $d (@dependents)
    {
        # AuxP attached to AuxP (or AuxC to AuxC, or even AuxC to AuxP or AuxP to AuxC) means a multi-word preposition (conjunction).
        if($self->is_deprel($d->deprel(), 'auxpc1'))
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
        return undef;
    }
    # Now it is clear that we have a prepositional phrase.
    # If this is currently an ordinary NTerm phrase, its head is the preposition (or subordinating conjunction).
    # However, it is also possible that we have a special phrase such as coordination.
    # Then we cannot just take the head. The whole core of the phrase is the preposition.
    # (For coordinate prepositions, consider "the box may be on or under the table".)
    # Therefore we will return the whole phrase as the preposition (the caller will later remove its dependents and keep the core).
    # For ordinary NTerm phrases this will add one unnecessary (but harmless) layer around the head.
    my $preposition = $phrase;
    # If there are two or more argument candidates, we have to select the best one.
    # There may be more sophisticated approaches but let's just take the first one for the moment.
    # Emphasizers (AuxZ) preceding the preposition should be attached to the argument
    # rather than the preposition. However, occasionally they are attached to the preposition, as in [cs]:
    #   , přinejmenším pokud jde o platy
    #   , at-least if are-concerned about salaries
    # ("pokud" is the AuxC and the original head, "přinejmenším" should be attached to the verb "jde" but it is
    # attached to "pokud", thus "pokud" has two children. We want the verb "jde" to become the argument.)
    # Similarly [cs]:
    #   třeba v tom
    #   for-example in the-fact
    # In this case, "třeba" is attached to "v" as AuxY (cc), not as AuxZ (advmod:emph).
    my @ecandidates = grep {$self->is_deprel($_->deprel(), 'auxyz')} (@candidates);
    my @ocandidates = grep {!$self->is_deprel($_->deprel(), 'auxyz')} (@candidates);
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
    my %classification =
    (
        'fun' => $preposition,
        'mwe' => \@mwauxp,
        'arg' => $argument,
        'dep' => [@candidates, @punc]
    );
    return \%classification;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

There are methods that detect structures in a Prague-style treebank (such as
the Czech Prague Dependency Treebank).

Transformations organized bottom-up during phrase building are advantageous
because we can rely on that all special structures (such as coordination) on the
lower levels have been detected and treated properly so that we will not
accidentially destroy them.

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

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
