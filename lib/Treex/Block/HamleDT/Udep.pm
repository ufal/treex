package Treex::Block::HamleDT::Udep;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has 'last_file_stem' => ( is => 'rw', isa => 'Str', default => '' );
has 'sent_in_file'   => ( is => 'rw', isa => 'Int', default => 0 );



#------------------------------------------------------------------------------
# Reads a Prague-style tree and transforms it to Universal Dependencies.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    # Add the name of the input file and the number of the sentence inside
    # the file as a comment that will be written in the CoNLL-U format.
    # (In any case, Write::CoNLLU will print the sentence id. But this additional
    # information is also very useful for debugging, as it ensures a user can find the sentence in Tred.)
    my $bundle = $zone->get_bundle();
    my $file_stem = $bundle->get_document()->file_stem();
    if($file_stem eq $self->last_file_stem())
    {
        $self->set_sent_in_file($self->sent_in_file() + 1);
    }
    else
    {
        $self->set_last_file_stem($file_stem);
        $self->set_sent_in_file(1);
    }
    my $sent_in_file = $self->sent_in_file();
    my $comment = "orig_file_sentence $file_stem\#$sent_in_file";
    my @comments;
    if(defined($bundle->wild()->{comment}))
    {
        @comments = split(/\n/, $bundle->wild()->{comment});
    }
    unless(any {$_ eq $comment} (@comments))
    {
        push(@comments, $comment);
        $bundle->wild()->{comment} = join("\n", @comments);
    }
    # Now the harmonization proper.
    my $root = $zone->get_atree();
    $self->exchange_tags($root);
    $self->shape_coordination_stanford($root);
    $self->restructure_compound_prepositions($root);
    $self->push_prep_sub_down($root);
    $self->push_copulas_down($root);
    $self->afun_to_udeprel($root);
    $self->attach_final_punctuation_to_predicate($root);
    $self->fix_determiners($root);
    $self->classify_numerals($root);
    $self->restructure_compound_numerals($root);
    $self->push_numerals_down($root);
    # Sanity checks.
    $self->check_determiners($root);
}



#------------------------------------------------------------------------------
# Replaces the tag from the original corpus by the corresponding Universal POS
# tag; saves the original tag in conll/pos instead. This would be done also in
# Write::CoNLLU. But even if we write Treex and view it in Tred, we want the UD
# tree to display the UPOS tags.
#------------------------------------------------------------------------------
sub exchange_tags
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $original_tag = $node->tag();
        $node->set_tag($node->iset()->get_upos());
        $node->set_conll_pos($original_tag);
    }
}



#------------------------------------------------------------------------------
# Convert analytical functions to universal dependency relations.
#------------------------------------------------------------------------------
sub afun_to_udeprel
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        $afun = '' if(!defined($afun));
        # If there were transformations that already set the deprel, take it into account.
        # Otherwise derive a default deprel from the afun.
        my $udep = $node->conll_deprel();
        $udep = 'dep:'.$afun if(!defined($udep));
        my $parent = $node->parent();
        # Predicate or ExD child of the root:
        # It is labeled root, regardless of whether the afun is Pred or ExD.
        ###!!! TODO: But beware of coordination!
        if($parent->is_root())
        {
            $udep = 'root';
        }
        # Predicate: If the node is not the main predicate of the sentence and it has the Pred afun,
        # then it is probably the main predicate of a parenthetical expression.
        elsif($afun eq 'Pred')
        {
            $udep = 'parataxis';
        }
        # Subject: nsubj, nsubjpass, csubj, csubjpass
        elsif($afun eq 'Sb')
        {
            # Is the parent a passive verb?
            ###!!! This will not catch reflexive passives. TODO: Catch them.
            if($parent->iset()->is_passive())
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $udep = $node->is_verb() ? 'csubjpass' : 'nsubjpass';
            }
            else # Parent is not passive.
            {
                # If this is a verb (including infinitive) then it is a clausal subject.
                $udep = $node->is_verb() ? 'csubj' : 'nsubj';
            }
        }
        # Object: dobj, iobj, ccomp, xcomp
        elsif($afun eq 'Obj')
        {
            ###!!! If a verb has two or more objects, we should select one direct object and the others will be indirect.
            ###!!! We would probably have to consider all valency frames to do that properly.
            ###!!! TODO: An approximation that we probably could do in the meantime is that
            ###!!! if there is one accusative and one or more non-accusatives, then the accusative is the direct object.
            # If this is an infinitive then it is an xcomp (controlled clausal complement).
            # If this is a verb form other than infinitive then it is a ccomp.
            ###!!! TODO: But if the infinitive is part of periphrastic future, then it is ccomp, not xcomp!
            $udep = $node->is_verb() ? ($node->is_infinitive() ? 'xcomp' : 'ccomp') : 'dobj';
        }
        # Adverbial modifier: advmod, nmod, advcl
        # Note: UD also distinguishes the relation neg. In Czech, most negation is done using bound morphemes.
        # Separate negative particles exist but they are either ExD (replacing elided negated "to be") or AuxZ ("ne poslední zvýšení cen").
        # Examples: ne, nikoli, nikoliv, ani?, vůbec?
        # I am not sure that we want to distinguish them from the other AuxZ using the neg relation.
        # AuxZ words are mostly adverbs, coordinating conjunctions and particles. Other parts of speech are extremely rare.
        elsif($afun eq 'Adv')
        {
            ###!!! TODO: Important question: Did we restructure prepositional phrases before entering this method?
            ###!!! Can an Adv depend on an AuxP or AuxC?
            $udep = $node->is_verb() ? 'advcl' : $node->is_noun() ? 'nmod' : 'advmod';
        }
        # Copula has been reattached under the nominal predicate, which was originally Pnom.
        # The Cop afun does not occur in PDT; it is a result of the reattachment.
        elsif($afun eq 'Cop')
        {
            $udep = 'cop';
        }
        # Attribute of a noun: amod, nummod, nmod, acl
        elsif($afun eq 'Atr')
        {
            # Cardinal number is nummod, ordinal number is amod. It should not be a problem because Interset should categorize ordinals as special types of adjectives.
            # But we cannot use the is_numeral() method because it returns true if pos=num or if numtype is not empty.
            # We also want to exclude pronominal numerals (kolik, tolik, mnoho, málo). These should be det.
            if($node->iset()->pos() eq 'num')
            {
                if($node->iset()->prontype() eq '')
                {
                    # If we later push the numeral down, we will label it nummod:gov.
                    $udep = 'nummod';
                }
                else
                {
                    # If we later push the quantifier down, we will label it det:numgov.
                    $udep = 'det:nummod';
                }
            }
            elsif($node->iset()->nametype() =~ m/(giv|sur|prs)/ &&
                  $parent->iset()->nametype() =~ m/(giv|sur|prs)/)
            {
                $udep = 'name';
            }
            elsif($node->is_foreign() && $parent->is_foreign())
            {
                $udep = 'foreign';
            }
            elsif($node->is_adjective() && $node->is_pronoun() && $self->agree($node, $parent, 'case'))
            {
                $udep = 'det';
            }
            elsif($node->is_adjective())
            {
                $udep = 'amod';
            }
            elsif($node->is_verb())
            {
                $udep = 'acl';
            }
            else
            {
                $udep = 'nmod';
            }
        }
        # Verbal attribute is analyzed as secondary predication.
        ###!!! TODO: distinguish core arguments (xcomp) from non-core arguments and adjuncts (acl/advcl).
        elsif($afun =~ m/^AtvV?$/)
        {
            $udep = 'xcomp';
        }
        # Auxiliary verb "být" ("to be"): aux, auxpass
        elsif($afun eq 'AuxV')
        {
            $udep = $parent->iset()->is_passive() ? 'auxpass' : 'aux';
            # Side effect: We also want to modify Interset. The PDT tagset does not distinguish auxiliary verbs but UPOS does.
            $node->iset()->set('verbtype', 'aux');
        }
        # Reflexive pronoun "se", "si" with mandatorily reflexive verbs.
        elsif($afun eq 'AuxT')
        {
            $udep = 'compound:reflex';
        }
        # Reflexive pronoun "se", "si" used for reflexive passive.
        elsif($afun eq 'AuxR')
        {
            $udep = 'auxpass:reflex';
        }
        # AuxZ: intensifier or negation
        elsif($afun eq 'AuxZ')
        {
            # Negation is mostly done using bound prefix ne-.
            # If it is a separate word ("ne už personálním, ale organizačním"; "potřeboval čtyřnohého a ne dvounohého přítele), it is labeled AuxZ.
            if($node->lemma() eq 'ne')
            {
                $udep = 'neg';
            }
            # AuxZ is an emphasizing word (“especially on Monday”).
            # It also occurs with numbers (“jen čtyři firmy”, “jen několik procent”).
            # The word "jen" ("only") is not necessarily a restriction. It rather emphasizes that the number is a restriction.
            # On the tectogrammatical layer these words often get the functor RHEM (rhematizer / rematizátor = něco, co vytváří réma, fokus).
            # But this is not a 1-1 mapping.
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch10s06.html
            # https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch07s07s05.html
            # Most frequent lemmas with AuxZ: i (4775 výskytů), jen, až, pouze, ani, už, již, ještě, také, především (689 výskytů)
            # Most frequent t-lemmas with RHEM: #Neg (7589 výskytů), i, jen, také, už, již, ani, až, pouze, například (500 výskytů)
            else
            {
                $udep = 'advmod:emph';
            }
        }
        # AuxY: Additional conjunction in coordination ... it has been relabeled during processing of coordinations.
        # AuxY: "jako" attached to Atv ... case
        elsif($afun eq 'AuxY')
        {
            $udep = 'case';
        }
        # AuxO: redundant "to" or "si" ("co to znamená pátý postulát dokázat").
        elsif($afun eq 'AuxO')
        {
            $udep = 'discourse';
        }
        # Apposition
        elsif($afun eq 'Apposition')
        {
            $udep = 'appos';
        }
        # Punctuation
        elsif($afun =~ m/^Aux[XGK]$/)
        {
            $udep = 'punct';
        }
        ###!!! TODO: ExD with chains of orphans should be stanfordized!
        elsif($afun eq 'ExD')
        {
            # Some ExD are vocatives.
            if($node->iset()->case() eq 'voc')
            {
                $udep = 'vocative';
            }
            else
            {
                $udep = 'dep';
            }
        }
        # Previous transformation of coordination to the Stanford style caused that afuns of some nodes
        # actually are already universal dependency relations.
        elsif($afun =~ m/^(conj|cc|punct|case|mark)$/)
        {
            $udep = $afun;
        }
        # We may want to dedicate a new node attribute to the universal dependency relation label.
        # At present, conll/deprel is good enough and afun cannot be used because its value range is fixed.
        $node->set_conll_deprel($udep);
        # Remove the value of afun. It does not make sense in the restructured tree.
        # In addition, empty afun will make the value of conll/deprel visible in Tred.
        $node->set_afun(undef);
    }
}



#------------------------------------------------------------------------------
# Converts coordination from the Prague style to the Stanford style.
#------------------------------------------------------------------------------
sub shape_coordination_stanford
{
    my $self = shift;
    my $node = shift;
    # Proceed bottom-up. First process children, then the current node.
    my @children = $node->children();
    foreach my $child (@children)
    {
        $self->shape_coordination_stanford($child);
    }
    # After processing my children, some of them may have ceased to be my children and some new children may have appeared.
    # This is the result of restructuring a child coordination.
    # Get the new list of children. In addition, we now require that the list is ordered (we have to identify the first conjunct).
    @children = $node->get_children({ordered => 1});
    # We have a coordination if the current node's afun is Coord.
    if($node->afun() eq 'Coord')
    {
        # If we are a nested coordination, remember it. We will have to set is_member for the new head.
        my $current_coord_is_member = 0;
        if($node->is_member())
        {
            $current_coord_is_member = 1;
            $node->set_is_member(0);
        }
        # Get conjuncts.
        my @conjuncts = grep {$_->is_member()} @children;
        my @dependents = grep {!$_->is_member()} @children;
        if(scalar(@conjuncts)==0)
        {
            log_warn('Coordination without conjuncts');
            # There must not be any node labeled Coord and having no is_member children.
            $node->set_afun('AuxY');
        }
        else
        {
            # Set the first conjunct as the new head.
            # Its afun should be already OK. It should not be a nested Coord because we processed the children first.
            my $head = shift(@conjuncts);
            $head->set_parent($node->parent());
            $head->set_is_member($current_coord_is_member);
            # Re-attach the current node and all its children to the new head.
            # Mark conjuncts using the UD relation conj.
            foreach my $conjunct (@conjuncts)
            {
                $conjunct->set_parent($head);
                $conjunct->set_afun('conj');
                $conjunct->set_conll_deprel('conj');
                # Clear the is_member flag for all conjuncts. It only made sense in the Prague style.
                $conjunct->set_is_member(0);
            }
            foreach my $dependent (@dependents, $node)
            {
                $dependent->set_parent($head);
                if($dependent->is_punctuation())
                {
                    $dependent->set_afun('punct');
                    $dependent->set_conll_deprel('punct');
                }
                elsif($dependent->afun() =~ m/^(Coord|AuxY)$/)
                {
                    $dependent->set_afun('cc');
                    $dependent->set_conll_deprel('cc');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Identifies multi-word prepositions and restructures them according to the UD
# guidelines.
#------------------------------------------------------------------------------
sub restructure_compound_prepositions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # Example multi-word preposition: na rozdíl od (in contrast to).
    # Original annotation: "od" is head, "na" and "rozdíl" depend on it. All three labeled "AuxP". The noun is attached to "od".
    # Desired annotation: "na" is head, "rozdíl" and "od" depend on it, labeled "mwe". "na" is attached to the noun and labeled "case".
    # Most compound prepositions consist of three nodes, some consist of two but we will not apriori restrict the number of nodes.
    for(my $i = 0; $i < $#nodes; $i++)
    {
        my $iord = $nodes[$i]->ord();
        # We cannot identify parts of compound preposition using the POS tag because some parts are nouns.
        # We must use the original dependency label (analytical function) because it has not yet been converted.
        if(defined($nodes[$i]->afun()) && $nodes[$i]->afun() eq 'AuxP' && $nodes[$i]->is_leaf())
        {
            my $parent = $nodes[$i]->parent();
            my $pord = $parent->ord();
            if($pord > $iord && defined($parent->afun()) && $parent->afun() eq 'AuxP')
            {
                my $found = 1;
                my @mwe;
                # We seem to have found a multi-word preposition. Make sure that all nodes between child and parent comply.
                for(my $j = $i+1; $nodes[$j] != $parent; $j++)
                {
                    if(!defined($nodes[$j]->afun()) || $nodes[$j]->afun() ne 'AuxP' || !$nodes[$j]->is_leaf() || $nodes[$j]->parent() != $parent)
                    {
                        $found = 0;
                        last;
                    }
                    push(@mwe, $nodes[$j]);
                }
                if($found)
                {
                    # $nodes[$i] is the first token of the MWE and the new head.
                    # @mwe contains the internal tokens of the MWE, usually just one middle token.
                    # $parent is the last token of the MWE and the old head.
                    $nodes[$i]->set_parent($parent->parent());
                    foreach my $n (@mwe, $parent)
                    {
                        $n->set_parent($nodes[$i]);
                        $n->set_afun(undef);
                        $n->set_conll_deprel('mwe');
                    }
                    # Re-attach all other children of the original head to the new head.
                    # There should be at least one child (the noun) and possibly also some punctuation etc.
                    my @children = $parent->children();
                    foreach my $child (@children)
                    {
                        $child->set_parent($nodes[$i]);
                    }
                    # Move index to the last word of the MWE, i.e. to the old $parent.
                    $i += scalar(@mwe)+1;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Reattach prepositions as dependents of their noun phrases.
# Reattach subordinating conjunctions as dependents of their clauses.
# Assumption: Coordination has already been converted to Stanford style.
#------------------------------------------------------------------------------
sub push_prep_sub_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        $afun = '' if(!defined($afun));
        if($afun eq 'AuxP')
        {
            # In the prototypical case, the node has just one child and it will swap positions with the child.
            ###!!! TODO: If the child is also Aux[PC], we should process the chain recursively.
            ###!!! TODO: First solve multi-word prepositions and all occurrences of leaf prepositions / subordinators.
            ###!!! TODO: Are there any prepositions with two or more arguments attached directly to them?
            ###!!! TODO: A preposition may have multiple children, one is its argument and the rest is Stanford coordination:
            ###!!!       ve městě a na vsi ... PrepArg(ve, městě), cc(ve, a), conj(ve, na), PrepArg(na, vsi)
            ###!!! TODO: On the other hand, if the argument of the preposition is coordination, the preposition should become a shared modifier of the coordination.
            ###!!! TODO: A preposition or subordinating conjunction may also have multiple children if there is punctuation.
            my @children = $self->get_children_of_auxp($node);
            if(scalar(@children)>0)
            {
                my $noun = shift(@children);
                $noun->set_parent($node->parent());
                $node->set_parent($noun);
                foreach my $child (@children)
                {
                    unless(defined($child->conll_deprel()) && $child->conll_deprel() eq 'mwe')
                    {
                        $child->set_parent($noun);
                    }
                }
            }
            # Even if the conjunction is already a leaf (which should not happen), it cannot keep the AuxC label.
            $node->set_afun('case');
            $node->set_conll_deprel('case');
        }
        elsif($afun eq 'AuxC')
        {
            my @children = $self->get_children_of_auxc($node);
            if(scalar(@children)>0)
            {
                my $verb = shift(@children);
                $verb->set_parent($node->parent());
                $node->set_parent($verb);
                foreach my $child (@children)
                {
                    $child->set_parent($verb);
                }
            }
            # Even if the conjunction is already a leaf (which should not happen), it cannot keep the AuxC label.
            $node->set_afun('mark');
            $node->set_conll_deprel('mark');
        }
    }
}



#------------------------------------------------------------------------------
# Identifies the main child of a preposition in the Prague style.
# There is typically just one child: the head of a noun phrase.
# But it is not guaranteed.
#
# The method returns the list of all children and the main child is the first
# member of the list, regardless of word order.
#------------------------------------------------------------------------------
sub get_children_of_auxp
{
    my $self = shift;
    my $preposition = shift; # afun = AuxP
    my @children = $preposition->get_children({ordered => 1});
    return @children if(scalar(@children) <= 1);
    # If there are nouns (including pronouns), find the first noun.
    # Skip nouns attached as "mwe", these are part of multi-word preposition (e.g. "na rozdíl od" = "in contrast to").
    # Note: If coordination has been restructured (recommended!), coordination of noun phrases is represented by a noun, not by a coordinating conjunction.
    for(my $i = 0; $i<=$#children; $i++)
    {
        if($children[$i]->is_noun() && !(defined($children[$i]->conll_deprel()) && $children[$i]->conll_deprel() eq 'mwe'))
        {
            my $head = $children[$i];
            splice(@children, $i, 1);
            return ($head, @children);
        }
    }
    # There are no suitable nouns. Find the first non-punctuation node.
    for(my $i = 0; $i<=$#children; $i++)
    {
        if(!$children[$i]->is_punctuation())
        {
            my $head = $children[$i];
            splice(@children, $i, 1);
            return ($head, @children);
        }
    }
    # There is only punctuation. (This is weird. Has coordination been restructured first?)
    # We have to return something, so let's return the first node.
    # (We could also look for the first node to the right of the conjunction, but then we would have to take care for the possibility that all children are to the left.)
    return @children;
}



#------------------------------------------------------------------------------
# Identifies the main child of a subordinating conjunction in the Prague style.
# There are typically just two children: a comma and the predicate of the
# subordinate clause. But it is not guaranteed.
#
# The method returns the list of all children and the main child is the first
# member of the list, regardless of word order.
#------------------------------------------------------------------------------
sub get_children_of_auxc
{
    my $self = shift;
    my $conjunction = shift; # afun = AuxC
    my @children = $conjunction->get_children({ordered => 1});
    return @children if(scalar(@children) <= 1);
    # If there are verbs, find the first verb.
    # Note: If coordination has been restructured (recommended!), coordination of subordinated clauses is represented by a verb, not by a coordinating conjunction.
    for(my $i = 0; $i<=$#children; $i++)
    {
        if($children[$i]->is_verb())
        {
            my $head = $children[$i];
            splice(@children, $i, 1);
            return ($head, @children);
        }
    }
    # There are no verbs. Find the first non-punctuation node.
    for(my $i = 0; $i<=$#children; $i++)
    {
        if(!$children[$i]->is_punctuation())
        {
            my $head = $children[$i];
            splice(@children, $i, 1);
            return ($head, @children);
        }
    }
    # There is only punctuation. (This is weird. Has coordination been restructured first?)
    # We have to return something, so let's return the second node.
    # (We could also look for the first node to the right of the conjunction, but then we would have to take care for the possibility that all children are to the left.)
    my $head = $children[1];
    splice(@children, 1, 1);
    return ($head, @children);
}



#------------------------------------------------------------------------------
# Reattach copulas as dependents of their nominal predicates.
# Assumption: Coordination has already been converted to Stanford style.
#------------------------------------------------------------------------------
sub push_copulas_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        $afun = '' if(!defined($afun));
        if($afun eq 'Pnom')
        {
            my $pnom = $node;
            my $copula = $node->parent();
            my $grandparent = $copula->parent();
            if(defined($grandparent))
            {
                $pnom->set_parent($grandparent);
                $pnom->set_afun($copula->afun());
                # All other children of the copula will be reattached to the nominal predicate.
                # The copula will become a leaf.
                my @children = $copula->children();
                foreach my $child (@children)
                {
                    $child->set_parent($pnom);
                }
                $copula->set_parent($pnom);
                $copula->set_afun('Cop');
                $copula->set_conll_deprel('cop');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Reattach sentence-final punctuation to the main predicate.
# Assumption: Coordination has already been converted to Stanford style, thus
# any punctuation node attached directly to the root does not head coordination.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_predicate
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->children();
    my @pnodes = grep {$_->is_punctuation()} @nodes;
    my @npnodes = grep {!$_->is_punctuation()} @nodes;
    if(@npnodes)
    {
        my $predicate = $npnodes[-1];
        foreach my $pnode (@pnodes)
        {
            $pnode->set_parent($predicate);
            $pnode->set_conll_deprel('punct');
        }
    }
}



#------------------------------------------------------------------------------
# Changes some determiners to pronouns, based on syntactic annotation.
# The Interset driver of the PDT tagset divides pronouns to pronouns and
# determiners. It knows that some pronouns are capable of acting as determiners
# nevertheless, they can still be used as pronouns (replacing a noun phrase
# instead of modifying it). This method tries to figure out whether the word
# actually modifies a noun phrase as an adjective.
#
# Coordination must have been converted before calling this method, because we
# do not search for effective parent (e.g. in "některého žáka či žákyni").
# Dependency relation labels must have been converted to UD labels.
#------------------------------------------------------------------------------
sub fix_determiners
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_adjective() && $node->is_pronoun())
        {
            my $parent = $node->parent();
            my $change = 0; # do not change DET to PRON
            if(!$parent->is_root())
            {
                # The common pattern is that the parent is a noun (or pronoun) and that it follows the determiner.
                #  possessive: můj pes (my dog)
                #  demonstrative: ten pes (that dog)
                #  interrogative: který pes (which dog)
                #  indefinite: nějaký pes (some dog)
                #  total: každý pes (every dog)
                #  negative: žádný pes (no dog)
                # Sometimes the determiner can follow the noun, instead of preceding it.
                #  v Německu samém (in Germany itself)
                #  té naší (the our)
                #  to vše (that all)
                #  nás všechny (us all)
                # But we want to rule out genitive constructions where one genitive pronoun post-modifies a noun phrase.
                #  nabídka všech (offer of all) (genitive construction; the words do not agree in case)
                #  půl tuctu jich (half dozen of them) (genitive construction; the words agree in case because tuctu is incidentially also genitive, but they do not agree in number; in addition, "jich" is a non-possessive personal pronoun which should never become det)
                #  firmy All - Impex (foreign determiner All; it cannot agree in case because it does not have case)
                #  děvy samy (girls themselves) (the words agree in case but the afun is Atv, not Atr, thus we should not get through the 'amod' constraint above)
                # The tree has not changed from the Prague style except for coordination. Nominal predicates still depend on copulas.
                # If it does not modify a noun (adjective, pronoun), it is not a determiner.
                $change = 1 if(!$parent->is_noun() && !$parent->is_adjective());
                # If they do not agree, it is not a determiner.
                $change = 1 if(!$self->agree($node, $parent, 'case'));
                # The following Czech pronouns are never used as determiners:
                # - personal (not possessive) pronouns, including non-possessive reflexives
                # - *kdo, *co, nic
                # - "to" in the compound conjunction "a to"
                if($node->iset()->prontype() eq 'prs' && !$node->is_possessive() ||
                   $node->form() =~ m/(kdo|co|^nic)$/i)
                {
                    $change = 1;
                }
                elsif(lc($node->form()) eq 'to')
                {
                    my @children = $node->children();
                    if(any {lc($_->form()) eq 'a'} @children)
                    {
                        $change = 1;
                    }
                }
                # If it is attached via one of the following relations, it is a pronoun, not a determiner.
                ###!!! We include 'conj' because conjuncts are more often than not pronouns and we do not want to implement the correct treatment of coordinations.
                ###!!! Nevertheless it is possible that determiners are coordinated: "ochutnala můj i tvůj oběd".
                if($node->conll_deprel() =~ m/^(nsubj|dobj|iobj|xcomp|advmod|case|appos|conj|cc|discourse|parataxis|foreign|dep)$/)
                {
                    $change = 1;
                }
            }
            else
            {
                # Neither pronoun nor determiner normally depend directly on the root.
                # They do so only in the case of ellipsis. Then we will call them pronouns, not determiners (usually it is their verbal head what has been deleted).
                $change = 1;
            }
            if($change)
            {
                # Change DET to PRON by changing Interset part of speech from adj to noun.
                $node->iset()->set('pos', 'noun');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Checks agreement between two nodes in one Interset feature. An empty value
# agrees with everything (because it can be interpreted as "any value").
#------------------------------------------------------------------------------
sub agree
{
    my $self = shift;
    my $node1 = shift;
    my $node2 = shift;
    my $feature = shift;
    my $i1 = $node1->iset();
    my $i2 = $node2->iset();
    return 1 if($i1->get($feature) eq '' || $i2->get($feature) eq '');
    return 1 if($i1->get_joined($feature) eq $i2->get_joined($feature));
    # If one or both the nodes have multiple values of the feature and their
    # intersection is not empty, take it as agreement.
    my @v1 = $i1->get_list($feature);
    foreach my $v1 (@v1)
    {
        return 1 if($i2->contains($feature, $v1));
    }
    return 0;
}



#------------------------------------------------------------------------------
# Splits numeral types that have the same tag in the PDT tagset and the
# Interset decoder cannot distinguish them because it does not see the word
# forms.
#------------------------------------------------------------------------------
sub classify_numerals
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $iset = $node->iset();
        # Separate multiplicative numerals (jednou, dvakrát, třikrát) and
        # adverbial ordinal numerals (poprvé, podruhé, potřetí).
        if($iset->numtype() eq 'mult')
        {
            # poprvé, podruhé, počtvrté, popáté, ..., popadesáté, posté
            # potřetí, potisící
            if($node->form() =~ m/^po.*[éí]$/i)
            {
                $iset->set('numtype', 'ord');
            }
        }
        # Separate generic numerals
        # for number of kinds (obojí, dvojí, trojí, čtverý, paterý) and
        # for number of sets (oboje, dvoje, troje, čtvery, patery).
        elsif($iset->numtype() eq 'gen')
        {
            if($iset->variant() eq '1')
            {
                $iset->set('numtype', 'sets');
            }
        }
        # Separate agreeing adjectival indefinite numeral "nejeden" (lit. "not one" = "more than one")
        # from indefinite/demonstrative adjectival ordinal numerals (několikátý, tolikátý).
        elsif($node->is_adjective() && $iset->contains('numtype', 'ord') && $node->lemma() eq 'nejeden')
        {
            $iset->add('pos' => 'num', 'numtype' => 'card', 'prontype' => 'ind');
        }
    }
}



#------------------------------------------------------------------------------
# Identifies multi-word numerals and organizes them in chains.
#------------------------------------------------------------------------------
sub restructure_compound_numerals
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # We are looking for sequences of numerals where every two adjacent words
    # are connected with a dependency. The direction of the dependency does not
    # matter. If a numeral is tagged as noun (this could happen to "sto",
    # "tisíc", "milión", "miliarda"), the chain will not include them.
    for(my $i = 0; $i < $#nodes; $i++)
    {
        if($nodes[$i]->iset()->contains('numtype', 'card'))
        {
            my $chain_found = 0;
            for(my $j = $i+1; $j <= $#nodes; $j++)
            {
                if($nodes[$j]->iset()->contains('numtype', 'card') &&
                   ($nodes[$j]->parent() == $nodes[$j-1] || $nodes[$j-1]->parent() == $nodes[$j]))
                {
                    $chain_found = $j-$i;
                }
                else
                {
                    last;
                }
            }
            if($chain_found)
            {
                # Figure out the attachment of the whole chain to the outside world.
                my $minord = $nodes[$i]->ord();
                my $maxord = $nodes[$i+$chain_found]->ord();
                my $parent;
                my $deprel;
                # Incremental reshaping could create temporary cycles and Treex would not allow that.
                # Therefore first attach all participants to the root, then draw the links between them.
                for(my $j = $i; $j <= $i+$chain_found; $j++)
                {
                    my $old_parent_ord = $nodes[$j]->parent()->ord();
                    if($old_parent_ord < $minord || $old_parent_ord > $maxord)
                    {
                        $parent = $nodes[$j]->parent();
                        $deprel = $nodes[$j]->conll_deprel();
                    }
                    $nodes[$j]->set_parent($root);
                }
                # Collect all outside children of the numeral nodes.
                # Later we will attach them to the head numeral.
                my @children;
                for(my $j = $i; $j <= $i+$chain_found; $j++)
                {
                    push(@children, $nodes[$j]->children());
                }
                for(my $j = $i; $j < $i+$chain_found; $j++)
                {
                    $nodes[$j]->set_parent($nodes[$j+1]);
                    $nodes[$j]->set_conll_deprel('compound');
                }
                $nodes[$i+$chain_found]->set_parent($parent);
                $nodes[$i+$chain_found]->set_conll_deprel($deprel);
                foreach my $child (@children)
                {
                    $child->set_parent($nodes[$i+$chain_found]);
                }
                $i += $chain_found;
            }
        }
    }
}



#------------------------------------------------------------------------------
# Makes sure that numerals modify counted nouns, not vice versa. (In PDT, both
# directions are possible under certain circumstances.)
#------------------------------------------------------------------------------
sub push_numerals_down
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Look for genitive nouns and pronouns attached to a preposition.
        if($node->is_noun() && $node->iset()->case() eq 'gen')
        {
            my $noun = $node;
            my $number = $node->parent();
            if($number->is_cardinal())
            {
                $noun->set_parent($number->parent());
                # If the number was already attached as nummod, it does not tell us anything but we do not want to keep nummod for the noun head.
                my $deprel = $number->conll_deprel();
                $deprel = 'nmod' if($deprel eq 'nummod');
                $noun->set_conll_deprel($deprel);
                $number->set_parent($noun);
                $number->set_conll_deprel($number->iset()->prontype() eq '' ? 'nummod:gov' : 'det:numgov');
                # All children of the number, except for parts of compound number, must be re-attached to the noun because they modify the whole phrase.
                my @children = grep {$_->conll_deprel() ne 'compound'} $number->children();
                foreach my $child (@children)
                {
                    $child->set_parent($noun);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Sanity check: everything that is tagged DET must be attached as det.
#------------------------------------------------------------------------------
sub check_determiners
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = defined($node->form()) ? $node->form() : '<EMPTY>';
        my $pform = $node->parent()->is_root() ? '<ROOT>' : defined($node->parent()->form()) ? $node->parent()->form() : '<EMPTY>';
        my $npform;
        if($node->parent()->ord() < $node->ord())
        {
            $npform = "($pform) $form";
        }
        else
        {
            $npform = "$form ($pform)";
        }
        # Determiner is a pronominal adjective.
        if($node->is_adjective() && $node->is_pronoun())
        {
            if($node->conll_deprel() ne 'det')
            {
                log_warn($npform.' is tagged DET but is not attached as det but as '.$node->conll_deprel());
            }
        }
        elsif($node->conll_deprel() eq 'det')
        {
            if(!$node->is_adjective() || !$node->is_pronoun())
            {
                log_warn($npform.' is attached as det but is not tagged DET');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::Udep

Converts dependency trees from the HamleDT/Prague style to the Universal
Dependencies. This block is experimental. In the future, it may be split into
smaller blocks, moved elsewhere in the inheritance hierarchy or otherwise
rewritten. It is also possible (actually quite likely) that the current
Harmonize* blocks will be modified to directly produce Universal Dependencies,
which will become our new default central annotation style.

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
