package Treex::Block::HamleDT::AR::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Base'; # provides get_node_spanstring()



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        $self->fix_morphology($node);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    foreach my $node (@nodes)
    {
        $self->fix_constructions($node);
        $self->fix_annotation_errors($node);
    }
    # Certain node types are supposed to be leaves. If they have children, we
    # will raise the children. However, we can only do it after we have fixed
    # all deprels, thus it cannot be included in fix_constructions() above.
    foreach my $node (@nodes)
    {
        $self->fix_leaves($node);
    }
    # It is possible that we changed the form of a multi-word token.
    # Therefore we must re-generate the sentence text.
    #$root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Fixes known issues in part-of-speech and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $node = shift;
    my $lform = lc($node->form());
    my $lemma = $node->lemma();
    my $iset = $node->iset();
    my $deprel = $node->deprel();
    # In PDT, the word "přičemž" ("and/where/while") is tagged as SCONJ but attached as Adv (advmod).
    # Etymologically, it is a preposition fused with a pronoun ("při+čemž"). We will re-tag it as adverb.
    # Similar cases: "zato" ("in exchange for what", literally "za+to" = "for+it").
    # This one is typically grammaticalized as a coordinating conjunction, similar to "but".
    # In some occurrences, we have "sice-zato", which is similar to paired cc "sice-ale".
    # But that is not a problem, other adverbs have grammaticalized to conjunctions too.
    # On the other hand, the following should stay SCONJ and the relation should change to mark:
    # "jakoby" ("as if"), "dokud" ("while")
    if($lform =~ m/^(přičemž|zato)$/)
    {
        $iset->set_hash({'pos' => 'adv', 'prontype' => 'rel'});
    }
    # The word "plus" can be a noun or a mathematical conjunction. If it is
    # attached as 'cc', it should be conjunction.
    elsif($lform eq 'plus' && $deprel =~ m/^cc(:|$)/)
    {
        $iset->set_hash({'pos' => 'conj', 'conjtype' => 'oper'});
    }
    # These are symbols, not punctuation.
    elsif($lform =~ m/^[<>]$/)
    {
        $iset->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
}



#------------------------------------------------------------------------------
# Fixes dependency relations (tree topology or labels or both).
#------------------------------------------------------------------------------
sub fix_constructions
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    # Noun cannot be copula. Some pronouns can be copulas but then they cannot have children.
    if(($node->is_noun() && !$node->is_pronoun() ||
        $node->is_pronoun() && !$node->is_leaf) && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Neither noun nor pronoun can be auxiliary verb, case marker, subordinator, coordinator, adverbial modifier.
    elsif($node->is_noun() && $deprel =~ m/^(aux|case|mark|cc|advmod)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Adjective cannot be auxiliary, copula, case, mark, cc.
    elsif($node->is_adjective() && !$node->is_pronominal() && $deprel =~ m/^(aux|cop|case|mark|cc)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'amod';
        }
        else
        {
            $deprel = 'advmod';
        }
        $node->set_deprel($deprel);
    }
    # Pronoun cannot be nummod.
    elsif($node->is_pronoun() && $deprel =~ m/^nummod(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Some determiners could be copulas but then they cannot have children.
    elsif($node->is_determiner() && !$node->is_leaf() && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'det';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Determiner cannot be aux, advmod, case, mark, cc.
    elsif($node->is_determiner() && $deprel =~ m/^(aux|advmod|case|mark|cc)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'det';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Cardinal numeral cannot be aux, copula, case, mark, cc.
    elsif($node->is_numeral() && $deprel =~ m/^(aux|cop|case|mark|cc)(:|$)/)
    {
        $deprel = 'nummod';
        $node->set_deprel($deprel);
    }
    # Verb cannot be advmod.
    elsif($node->is_verb() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'advcl';
        $node->set_deprel($deprel);
    }
    # Verb should not be case, mark, cc.
    elsif($node->is_verb() && $deprel =~ m/^(case|mark|cc)(:|$)/)
    {
        $deprel = 'parataxis';
        $node->set_deprel($deprel);
    }
    # Preposition cannot be advmod. It could be oblique dependent if it is a
    # promoted orphan of a noun phrase. Or it is an annotation error and a
    # prepositional phrase stayed mistakenly headed by the preposition.
    elsif($node->is_adposition() && $deprel =~ m/^advmod(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Preposition cannot be copula.
    elsif($node->is_adposition() && $deprel =~ m/^cop(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'case';
        }
        else
        {
            $deprel = 'mark';
        }
    }
    # Conjunction cannot be copula, punctuation.
    elsif($node->is_conjunction() && $deprel =~ m/^(aux|cop|punct)(:|$)/)
    {
        $deprel = 'cc';
        $node->set_deprel($deprel);
    }
    # Some particles (e.g., "الا") are attached as aux or aux:pass and have children, which is inacceptable.
    elsif($node->is_particle() && !$node->is_leaf() && $deprel =~ m/^(aux|cop)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # Other particles are leaves, are correctly attached as aux but should also be tagged AUX.
    elsif($node->is_particle() && $node->is_leaf() && $deprel =~ m/^aux(:|$)/)
    {
        $node->set_tag('AUX');
        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux'});
    }
    # If we changed tag of a symbol from PUNCT to SYM above, we must also change
    # its dependency relation.
    elsif($node->is_symbol() && $deprel =~ m/^punct(:|$)/ &&
          $node->ord() > $parent->ord())
    {
        $deprel = 'flat';
        $node->set_deprel($deprel);
    }
    elsif($node->is_symbol() && $deprel =~ m/^punct(:|$)/)
    {
        $deprel = 'dep';
        $node->set_deprel($deprel);
    }
    # Unknown part of speech ('X') cannot be copula. One example that I saw was
    # an out-of-vocabulary proper noun but I do not know what the others are.
    elsif($node->iset()->pos() eq '' && $deprel =~ m/^(aux|cop)(:|$)/)
    {
        if($parent->is_noun())
        {
            $deprel = 'nmod';
        }
        else
        {
            $deprel = 'obl';
        }
        $node->set_deprel($deprel);
    }
    # There are some strange cases of right-to-left apposition. I do not
    # understand what is going on there and what should be the remedy. This is
    # just a temporary hack to silence the validator.
    elsif($deprel =~ m/^appos(:|$)/ && $parent->ord() > $node->ord())
    {
        $deprel = 'dislocated';
        $node->set_deprel($deprel);
    }
    $self->fix_auxiliary_verb($node);
}



#------------------------------------------------------------------------------
# Fix auxiliary verb that should not be auxiliary.
#------------------------------------------------------------------------------
sub fix_auxiliary_verb
{
    my $self = shift;
    my $node = shift;
    if($node->lemma() eq 'لسنا' && $node->tag() eq 'X' && $node->deprel() =~ m/^cop(:|$)/)
    {
        $node->set_tag('AUX');
        $node->iset()->add('pos' => 'verb', 'verbtype' => 'aux');
    }
    if($node->is_verb() && $node->deprel() =~ m/^cop(:|$)/)
    {
        if($node->lemma() !~ m/^(كَان|لَيس|لسنا)$/)
           # $node->lemma() =~ m/^صَرَّح$/ # ṣarraḥ
        {
            my $pnom = $node->parent();
            my $parent = $pnom->parent();
            my $deprel = $pnom->deprel();
            # The nominal predicate may have been attached as a non-clause;
            # however, now we have definitely a clause.
            $deprel =~ s/^nsubj/csubj/;
            $deprel =~ s/^i?obj/ccomp/;
            $deprel =~ s/^(advmod|obl)/advcl/;
            $deprel =~ s/^(nmod|amod|appos)/acl/;
            $node->set_parent($parent);
            $node->set_deprel($deprel);
            $pnom->set_parent($node);
            $pnom->set_deprel('xcomp');
            # Subject, adjuncts and other auxiliaries go up (also 'expl:pv' in "stát se").
            # Noun modifiers remain with the nominal predicate.
            my @children = $pnom->children();
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^([nc]subj|obj|obl|advmod|discourse|vocative|expl)(:|$)/)
                {
                    $child->set_parent($node);
                }
            }
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^(aux|mark|cc)(:|$)/)
                {
                    unless($self->would_be_nonprojective($node, $child) || $self->would_cause_nonprojectivity($node, $child))
                    {
                        $child->set_parent($node);
                    }
                }
            }
            # Sometimes punctuation must be raised because of nonprojectivity.
            # Sometimes punctuation causes nonprojectivity when raised.
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^punct(:|$)/)
                {
                    unless($self->would_be_nonprojective($node, $child) || $self->would_cause_nonprojectivity($node, $child))
                    {
                        $child->set_parent($node);
                    }
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->iset()->clear('verbtype');
            $node->set_tag('VERB');
        }
    }
}



#------------------------------------------------------------------------------
# Certain node types are supposed to be leaves. If they have children, we
# will raise the children. However, we can only do it after we have fixed
# all deprels, thus it cannot be included in fix_constructions() above.
#------------------------------------------------------------------------------
sub fix_leaves
{
    my $self = shift;
    my $node = shift;
    # Some types of dependents, such as 'conj', are allowed even under function
    # words.
    if($node->deprel() !~ m/^(root|fixed|goeswith|conj|punct)(:|$)/ &&
       $node->parent()->deprel() =~ m/^(det|cop|aux|case|mark|cc|fixed|goeswith|punct)(:|$)/)
    {
        my $grandparent = $node->parent()->parent();
        $node->set_parent($grandparent);
    }
}



#------------------------------------------------------------------------------
# Fixes various annotation errors in individual sentences. It is preferred to
# fix them when harmonizing the Prague style but in some cases the conversion
# would be still difficult, so we do it here.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $node = shift;
    my $spanstring = $self->get_node_spanstring($node);
    # Full sentence: Maďarský občan přitom zaplatí za: - 1 l mléka kolem 60
    # forintů, - 1 kg chleba kolem 70, - 1 lahev coca coly (0.33 l) kolem 15
    # forintů, - krabička cigaret Marlboro asi 120 forintů, - 1 l bezolovnatého
    # benzinu asi 76 forintů.
    if($spanstring =~ m/Maďarský občan přitom zaplatí za : -/)
    {
        my @subtree = $self->get_node_subtree($node);
    }
}



#------------------------------------------------------------------------------
# For a candidate attachment, tells whether it would be nonprojective. We want
# to use the relatively complex method Node->is_nonprojective(), which means
# that we must temporarily attach the node to the candidate parent. This will
# throw an exception if there is a cycle. But then we should not be considering
# the parent anyways.
#------------------------------------------------------------------------------
sub would_be_nonprojective
{
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    # Remember the current attachment of the child so we can later restore it.
    my $current_parent = $child->parent();
    # We could now check for potential cycles by calling $parent->is_descendant_of($child).
    # But it is not clear what we should do if the answer is yes. And at present,
    # this module does not try to attach punctuation nodes that are not leaves.
    $child->set_parent($parent);
    my $nprj = $child->is_nonprojective();
    # Restore the current parent.
    $child->set_parent($current_parent);
    return $nprj;
}



#------------------------------------------------------------------------------
# For a candidate attachment, tells whether it would cause a new
# nonprojectivity, provided the rest of the tree stays as it is. We want to
# use the relatively complex method Node->get_gap(), which means that we must
# temporarily attach the node to the candidate parent. This will throw an
# exception if there is a cycle. But then we should not be considering the
# parent anyways.
#------------------------------------------------------------------------------
sub would_cause_nonprojectivity
{
    my $self = shift;
    my $parent = shift;
    my $child = shift;
    # Remember the current attachment of the child so we can later restore it.
    my $current_parent = $child->parent();
    # We could now check for potential cycles by calling $parent->is_descendant_of($child).
    # But it is not clear what we should do if the answer is yes. And at present,
    # this module does not try to attach punctuation nodes that are not leaves.
    $child->set_parent($parent);
    # The punctuation node itself must not cause nonprojectivity of others.
    # If the gap contains other, non-punctuation nodes, we could hold those
    # other nodes responsible for the gap, but then the child would have to be
    # attached to them and not to something else. So we will consider any gap
    # a problem.
    my @gap = $child->get_gap();
    # Restore the current parent.
    $child->set_parent($current_parent);
    return scalar(@gap);
}



1;

=over

=item Treex::Block::HamleDT::AR::FixUD

Arabic-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
