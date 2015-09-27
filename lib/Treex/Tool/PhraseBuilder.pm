package Treex::Tool::PhraseBuilder;

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
        $phrase = $self->detect_colon_predicate($phrase);
        $phrase = $self->detect_prague_copula($phrase);
        $phrase = $self->detect_name_phrase($phrase);
        $phrase = $self->detect_compound_numeral($phrase);
        $phrase = $self->detect_counted_noun_in_genitive($phrase);
        $phrase = $self->detect_indirect_object($phrase);
        $phrase = $self->detect_controlled_verb($phrase);
        $phrase = $self->detect_controlled_subject($phrase);
    }
    else
    {
        $phrase = $self->detect_root_phrase($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
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
    my $phrase = shift; # Treex::Core::Phrase
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
                # Occasionally punctuation is labeled as conjunct (not nested coordination,
                # that should be solved by now, but an orphan leaf node after ellipsis).
                # We want to make it normal punctuation instead.
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
# Examines a nonterminal phrase in the Prague style (with analytical functions
# converted to dependency relation labels based on Universal Dependencies).
# If it recognizes a prepositional phrase, transforms the general NTerm to PP.
# A subordinate clause headed by AuxC is also treated as PP.
#------------------------------------------------------------------------------
sub detect_prague_pp
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the preposition (if any) must be the head.
    # The deprel is already partially converted to UD, so it should be something:auxp
    # (case:auxp, mark:auxp); see HamleDT::Udep->afun_to_udeprel().
    if($phrase->deprel() =~ m/^(case|mark):(aux[pc])/i)
    {
        my $target_deprel = $1;
        my $c = $self->classify_prague_pp_subphrases($phrase);
        # If there are no argument candidates, we cannot create a prepositional phrase.
        if(!defined($c))
        {
            # The ':auxp' or ':auxc' in deprel marked unprocessed prepositions and subordinating conjunctions.
            # Now that this one has been visited (even if we did not find the expected configuration) we must
            # remove this extension so that only known labels appear in the output.
            $phrase->set_deprel($target_deprel);
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
                $mwp->set_deprel('mwe');
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
        # Case attached to case (or mark to mark, or even mark to case or case to mark) means a multi-word preposition (conjunction).
        # The leaves used to be labeled AuxP (AuxC) and later case:auxp (mark:auxc). But we are working bottom-up. We have visited
        # the dependents, we were unable to construct a PP (because they have no children) but we removed the :aux[pc] from the label.
        if($d->deprel() =~ m/(case|mark)/i)
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
    # Emphasizers (AuxZ or advmod:emph) preceding the preposition should be attached to the argument
    # rather than the preposition. However, occasionally they are attached to the preposition, as in [cs]:
    #   , přinejmenším pokud jde o platy
    #   , at-least if are-concerned about salaries
    # ("pokud" is the AuxC and the original head, "přinejmenším" should be attached to the verb "jde" but it is
    # attached to "pokud", thus "pokud" has two children. We want the verb "jde" to become the argument.)
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
    my %classification =
    (
        'fun' => $preposition,
        'mwe' => \@mwauxp,
        'arg' => $argument,
        'dep' => [@candidates, @punc]
    );
    return \%classification;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style (with analytical functions
# converted to dependency relation labels based on Universal Dependencies).
# If it recognizes a copula construction, transforms the general NTerm to PP.
#------------------------------------------------------------------------------
sub detect_prague_copula
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the copula (if any) must be the head.
    # The deprel is already partially converted to UD, so there should be a child
    # labeled dep:pnom; see HamleDT::Udep->afun_to_udeprel().
    my @pnom = grep {$_->deprel() =~ m/pnom/i} ($phrase->dependents('ordered' => 1));
    if(scalar(@pnom)>=1)
    {
        # Now it is clear that we have a nominal predicate with copula.
        # If this is currently an ordinary NTerm phrase, its head is the copula.
        # However, it is also possible that we have a special phrase such as coordination.
        # Then we cannot just take the head. The whole core of the phrase is the copula.
        # (For coordinate copulas, consider "he is and always was the best goalkeeper".)
        # Therefore we will remove the dependents and keep the core phrase as the copula.
        # For ordinary NTerm phrases this will add one unnecessary (but harmless) layer around the head.
        my $copula = $phrase;
        # Note that the nominal predicate can also be seen as the argument of the copula,
        # and we will denote it as $argument here, which is the terminology inside Phrase::PP.
        my $argument;
        # There should not be more than one nominal predicate but it is not guaranteed.
        # There are about 40 sentences even in PDT; all of them are annotation errors.
        # We will try to identify the most probable predicate; but note that these
        # heuristics may be language-dependent.
        if(scalar(@pnom)==1)
        {
            $argument = shift(@pnom);
        }
        else
        {
            # Look for an adjective in nominative (or without case marking).
            my @selection = grep {$_->node()->is_adjective() && $_->node()->iset()->case() =~ m/^(nom)?$/} (@pnom);
            if(@selection)
            {
                $argument = shift(@selection);
            }
            else
            {
                # Look for a participle.
                @selection = grep {$_->node()->is_participle()} (@pnom);
                if(@selection)
                {
                    $argument = shift(@selection);
                }
                else
                {
                    # Look for a noun.
                    # (Specific for Czech: the noun will usually be in nominative or instrumental.
                    # But it can also be in genitive (transformed phrases with counted nouns).)
                    # We will not check the case here as the benefit is negligible.
                    # However, we will take the last noun, not the first one. A frequent annotation
                    # error is that the subject is labeled as Pnom, and the configuration where
                    # subject precedes predicate is more likely.
                    @selection = grep {$_->node()->is_noun()} (@pnom);
                    if(@selection)
                    {
                        $argument = pop(@selection);
                    }
                    else
                    {
                        # No typical nominal predicates found. Take the last candidate.
                        $argument = pop(@pnom);
                    }
                }
            }
            # The unselected candidates must receive a dependency relation label (at the moment they only have 'dep:pnom').
            my $subject_exists = any {$_->deprel() =~ m/subj/i} ($phrase->dependents());
            foreach my $x (@pnom)
            {
                unless($x == $argument)
                {
                    if($x->node()->is_noun() || $x->node()->is_adjective() || $x->node()->is_numeral() || $x->node()->is_participle())
                    {
                        if($subject_exists)
                        {
                            $x->set_deprel('nmod');
                        }
                        else
                        {
                            $x->set_deprel('nsubj');
                        }
                    }
                    else
                    {
                        $x->set_deprel('advmod');
                    }
                }
            }
        }
        my @dependents = grep {$_ != $argument} ($phrase->dependents());
        my $parent = $phrase->parent();
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $copula->set_parent(undef);
        $argument->set_parent(undef);
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $copula,
            'arg'           => $argument,
            'fun_is_head'   => $self->cop_is_head(),
            'deprel_at_fun' => 0,
            'is_member'     => $member
        );
        # Copula is sometimes represented by a punctuation sign (dash, colon) instead of the verb "to be".
        # Punctuation should not be attached as cop.
        if($copula->node()->is_punctuation())
        {
            $copula->set_deprel('punct');
        }
        else
        {
            $copula->set_deprel('cop');
        }
        $pp->set_deprel($deprel);
        $pp->set_parent($parent);
        foreach my $d (@dependents)
        {
            $d->set_parent($pp);
        }
        return $pp;
    }
    # Return the input phrase if no PP has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Looks for name phrases, i.e. two or more proper nouns connected by the name
# relation. Makes sure that the leftmost name is the head (usually the opposite
# to PDT where family names are heads and given names are dependents). The
# method currently does not search for nested name phrases (which, if they
# they exist, we might want to merge with the current level).
#------------------------------------------------------------------------------
sub detect_name_phrase
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Are there any non-core children attached as name?
    my @dependents = $phrase->dependents();
    my @name = grep {$_->deprel() eq 'name'} (@dependents);
    if(scalar(@name)>=1)
    {
        my @nonname = grep {$_->deprel() ne 'name'} (@dependents);
        # If there are name children, then the current phrase is a name, too.
        # Detach the dependents first, so that we can put the current phrase on the same level with the other names.
        foreach my $d (@dependents)
        {
            $d->set_parent(undef);
        }
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Add the current phrase (without dependents) to the names and order them.
        push(@name, $phrase);
        @name = sort {$a->ord() <=> $b->ord()} (@name);
        # Create a new nonterminal phrase for the name only.
        # (In the future we may also want to create a new subclass of nonterminal
        # phrases specifically for head-first multi-word segments. But it is not
        # necessary for transformations to work, so let's keep this for now.)
        my $namephrase = new Treex::Core::Phrase::NTerm('head' => shift(@name));
        foreach my $n (@name)
        {
            $n->set_parent($namephrase);
            $n->set_deprel('name');
            $n->set_is_member(0);
        }
        # Create a new nonterminal phrase that will group the name phrase with
        # the original non-name dependents, if any.
        if(scalar(@nonname)>=1)
        {
            $phrase = new Treex::Core::Phrase::NTerm('head' => $namephrase);
            foreach my $d (@nonname)
            {
                $d->set_parent($phrase);
                $d->set_is_member(0);
            }
        }
        else
        {
            $phrase = $namephrase;
        }
        $phrase->set_deprel($deprel);
        $phrase->set_is_member($member);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Looks for compound numeral phrases, i.e. two or more cardinal numerals
# connected by the nummod relation. Changes the relation to compound. This
# method does not care whether the relation goes left-to-right or right-to-left
# and whether there are nested compounds (or a multi-level compound).
#------------------------------------------------------------------------------
sub detect_compound_numeral
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Is the head a cardinal numeral and are there non-core children that are
    # cardinal numerals?
    my @dependents = $phrase->dependents();
    my @cnum = grep {$_->node()->is_cardinal() && $_->node()->iset()->prontype() eq ''} (@dependents);
    if($phrase->node()->is_cardinal() && $phrase->node()->iset()->prontype() eq '' && scalar(@cnum)>=1)
    {
        my @rest = grep {!$_->node()->is_cardinal() || $_->node()->iset()->prontype() ne ''} (@dependents);
        # The current phrase is a number, too.
        # Detach the dependents first, so that we can put the current phrase on the same level with the other names.
        foreach my $d (@dependents)
        {
            $d->set_parent(undef);
        }
        my $deprel = $phrase->deprel();
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Create a new nonterminal phrase for the compound numeral only.
        my $cnumphrase = new Treex::Core::Phrase::NTerm('head' => $phrase);
        foreach my $n (@cnum)
        {
            $n->set_parent($cnumphrase);
            $n->set_deprel('compound');
            $n->set_is_member(0);
        }
        # Create a new nonterminal phrase that will group the numeral phrase with
        # the original non-numeral dependents, if any.
        if(scalar(@rest)>=1)
        {
            $phrase = new Treex::Core::Phrase::NTerm('head' => $cnumphrase);
            foreach my $d (@rest)
            {
                $d->set_parent($phrase);
                $d->set_is_member(0);
            }
        }
        else
        {
            $phrase = $cnumphrase;
        }
        $phrase->set_deprel($deprel);
        $phrase->set_is_member($member);
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Makes sure that numerals modify counted nouns, not vice versa. (In PDT, both
# directions are possible under certain circumstances.)
#------------------------------------------------------------------------------
sub detect_counted_noun_in_genitive
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Is the head a cardinal numeral and are there non-core children that are
    # nominals (nouns or pronouns) in genitive? Do not count genitives with
    # adpositions (e.g. [cs] "5 ze 100 obyvatel", "5 per 100 inhabitants").
    if($phrase->node()->is_cardinal())
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        my @gen;
        my @rest;
        # Find counted noun in genitive.
        foreach my $d (@dependents)
        {
            my $ok = $d->node()->is_noun() && $d->node()->iset()->case() eq 'gen';
            if($ok)
            {
                my @dchildren = $d->children();
                $ok = $ok && !any {$_->node()->is_adposition()} (@dchildren);
                $ok = $ok && $d->deprel() ne 'appos';
            }
            if($ok)
            {
                push(@gen, $d);
            }
            else
            {
                push(@rest, $d);
            }
        }
        if(scalar(@gen)>=1)
        {
            # We do not expect more than one genitive noun phrase. If we encounter them,
            # we will just take the first one and treat the others as normal dependents.
            my $counted_noun = shift(@gen);
            push(@rest, @gen) if(@gen);
            # We may not be able to just set the counted noun as the new head. If it is a Coordination, there are other rules for finding the head.
            ###!!! Maybe we should extend the set_head() method to special nonterminals? It would create an extra NTerm phrase, move the dependents
            ###!!! there and set the core as its head? That's what we will do here anyway, and it has been needed repeatedly.
            # Detach the counted noun but not the other dependents. If there is anything else attached directly to the numeral,
            # it should probably stay there. Example [cs]: "ze 128 křesel jich 94 připadne..." "jich" is the counted nominal, "94" is the number
            # and "ze 128 křesel" ("out of 128 seats") modifies the number, not the nominal.
            # Unfortunately there are also counterexamples and from the original Prague annotation we cannot decide what modifies the numeral and what the counted noun.
            # If the noun is "procent" or "kilometrů", then it is quite likely that the modifier should be attached to the nominal ("31.5 kilometru od pobřeží").
            $counted_noun->set_parent(undef);
            my $deprel = $phrase->deprel();
            my $member = $phrase->is_member();
            $phrase->set_is_member(0);
            # If the deprel convertor returned nummod or its relatives, it means that the whole phrase (numeral+nominal)
            # originally modified another nominal as Atr. Since the counted noun is now going to head the phrase, we
            # have to change the deprel to nmod. We would not change the deprel if it was nsubj, dobj, appos etc.
            if($deprel =~ m/^(nummod|nummod:gov|det:nummod|det:numgov)$/)
            {
                $deprel = 'nmod';
            }
            # Create a new nonterminal phrase with the counted noun as the head.
            my $ntphrase = new Treex::Core::Phrase::NTerm('head' => $counted_noun);
            # Attach the numeral also as a dependent to the new phrase.
            $phrase->set_parent($ntphrase);
            $phrase->set_deprel($phrase->node()->iset()->prontype() eq '' ? 'nummod:gov' : 'det:numgov');
            $phrase->set_is_member(0);
            $phrase = $ntphrase;
            $phrase->set_deprel($deprel);
            $phrase->set_is_member($member);
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# The Prague treebanks do not distinguish direct and indirect objects. There is
# only one object relation, Obj. In Universal Dependencies we have to select
# one object of each verb as the main one (dobj), the others should be labeled
# as indirect (iobj). There is no easy way of doing this, but we can use a few
# heuristics to solve at least some cases.
#------------------------------------------------------------------------------
sub detect_indirect_object
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Only look for objects under verbs.
    if($phrase->node()->is_verb())
    {
        my @dependents = $phrase->dependents();
        # If there is a clausal complement (ccomp or xcomp), we assume that it
        # takes the role of the direct object. Any other object will be labeled
        # as indirect.
        if(any {$_->deprel() =~ m/^[cx]comp$/} (@dependents))
        {
            foreach my $d (@dependents)
            {
                if($d->deprel() eq 'dobj')
                {
                    $d->set_deprel('iobj');
                }
            }
        }
        # If there is an accusative object without preposition, all other objects are indirect.
        elsif(any {$_->deprel() eq 'dobj' && $self->get_phrase_case($_) eq 'acc'} (@dependents))
        {
            foreach my $d (@dependents)
            {
                if($d->deprel() eq 'dobj' && $self->get_phrase_case($d) ne 'acc')
                {
                    $d->set_deprel('iobj');
                }
            }
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Clausal complements should be labeled ccomp or xcomp, whereas xcomp is
# reserved for controlled verbs whose subject is inherited from the controlling
# verb. This means (at least in some languages) that the controlled verb is in
# infinitive. However, we have to check that the infinitive form is not caused
# by the periphrastic future tense (cs: "bude následovat"). In such cases the
# whole verb group (auxiliary + main verb) is actually finite and uncontrolled.
# They have their own subject independent of the governing verb (cs: "Ti
# odhadují, že po uvolnění cen nebude následovat jejich okamžitý vzestup.")
#------------------------------------------------------------------------------
sub detect_controlled_verb
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Only look for clausal complements headed by verbs.
    # We assume that ccomp has been initially changed to xcomp wherever infinitive was seen,
    # so now we only check that the infinitive is genuine.
    if($phrase->node()->is_infinitive() && $phrase->deprel() eq 'xcomp')
    {
        my @dependents = $phrase->dependents();
        if(any {$_->deprel() eq 'aux' && $_->node()->iset()->tense() eq 'fut'} (@dependents))
        {
            $phrase->set_deprel('ccomp');
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Infinitives controlled by other verbs (xcomp) cannot have their own subject.
# The subject must be attached directly to the controlling verb. This rule
# holds even in the Prague treebanks but it is occasionally violated due to
# annotation errors. This method tries to detect such instances and fix them.
# It must not be called before xcomp labels are fixed (see detect_controlled_
# verb() above)!
#------------------------------------------------------------------------------
sub detect_controlled_subject
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Look for controlling verb that does not have its own overt subject.
    if($phrase->node()->is_verb())
    {
        my @dependents = $phrase->dependents();
        my @controlled_infinitives = grep {$_->deprel() eq 'xcomp' && $_->node()->is_infinitive()} (@dependents);
        my $has_subject = any {$_->deprel() =~ m/^[nc]subj(pass)?(:|$)/} (@dependents);
        if(scalar(@controlled_infinitives)>0 && !$has_subject)
        {
            # It is not clear what we should do if there is more than one infinitive and they are not in coordination.
            # We assume that there should be just one and we will take the first one if there are more.
            # If there is a coordination of infinitives, we can only fix the error if they share one subject.
            # If the subject(s) is (are) attached as private dependents of the conjuncts, we will not fix them.
            my $infinitive = shift(@controlled_infinitives);
            my @subjects = grep {$_->deprel() =~ m/^[nc]subj(pass)?(:|$)/} ($infinitive->dependents());
            if(scalar(@subjects)>0)
            {
                # Again, more than one subject (uncoordinate) does not make sense. Let's take the first one.
                my $subject = shift(@subjects);
                $subject->set_parent($phrase);
            }
        }
    }
    return $phrase;
}



#------------------------------------------------------------------------------
# Figures out the generalized case of a phrase, consisting of word forms of any
# children with the 'case' relation, and the value of the morphological case of
# the head word.
#------------------------------------------------------------------------------
sub get_phrase_case
{
    my $self = shift;
    my $phrase = shift;
    my $case = '';
    my $node = $phrase->node();
    # Prepositions may also have the case feature but in their case it is valency, i.e. the required case of their nominal argument.
    unless($node->is_adposition())
    {
        # Does the phrase have any children (probably core children) attached as case?
        my @children = $phrase->children();
        my @case_forms = map {$_->node()->form()} (grep {$_->deprel() eq 'case'} (@children));
        # Does the head node have the case feature?
        my $head_case = $node->iset()->case();
        push(@case_forms, $head_case) unless($head_case eq '');
        if(@case_forms)
        {
            $case = join('+', @case_forms);
        }
    }
    return $case;
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
                # If a Pnom was attached directly to the root (e.g. in Arabic), it did not go through the copula inversion
                # and its deprel is still dep:pnom. Change it to something compatible with Universal Dependencies.
                if($d->deprel() eq 'dep:pnom')
                {
                    $d->set_deprel('parataxis');
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

Treex::Tool::PhraseBuilder

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

There are methods that detect structures in a Prague-style treebank (such as
the Czech Prague Dependency Treebank), with dependency relation labels
(analytical functions) converted to Universal Dependencies (see
C<Treex::Block::HamleDT::Udep> for details). All restructuring and relabeling
done here is directed towards the Universal Dependencies annotation style.

Transformations organized bottom-up during phrase building are advantageous
because we can rely on that all special structures (such as coordination) on the
lower levels have been detected and treated properly so that we will not
accidentially destroy them.

In the future we will define other phrase builders for other annotation styles.

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

=item detect_name_phrase

Looks for name phrases, i.e. two or more proper nouns connected by the name
relation. Makes sure that the leftmost name is the head (usually the opposite
to PDT where family names are heads and given names are dependents). The
method currently does not search for nested name phrases (which, if they
they exist, we might want to merge with the current level).

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

=item detect_controlled_verb

Clausal complements should be labeled C<ccomp> or C<xcomp>, whereas C<xcomp> is
reserved for controlled verbs whose subject is inherited from the controlling
verb. This means (at least in some languages) that the controlled verb is in
infinitive. However, we have to check that the infinitive form is not caused
by the periphrastic future tense (cs: I<bude následovat>). In such cases the
whole verb group (auxiliary + main verb) is actually finite and uncontrolled.
They have their own subject independent of the governing verb (cs: I<Ti
odhadují, že po uvolnění cen nebude následovat jejich okamžitý vzestup.>)

=item detect_controlled_subject

Infinitives controlled by other verbs (C<xcomp>) cannot have their own subject.
The subject must be attached directly to the controlling verb. This rule
holds even in the Prague treebanks but it is occasionally violated due to
annotation errors. This method tries to detect such instances and fix them.
It must not be called before xcomp labels are fixed (see detect_controlled_
verb() above)!

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
