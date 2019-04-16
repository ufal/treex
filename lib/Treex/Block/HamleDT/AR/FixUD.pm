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
    # Noun cannot be copula.
    if($node->is_noun() && !$node->is_pronoun() && $deprel =~ m/^cop(:|$)/)
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
    # Neither noun nor pronoun can be case marker, subordinator, coordinator, adverbial modifier.
    elsif($node->is_noun() && $deprel =~ m/^(case|mark|cc|advmod)(:|$)/)
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
    # Adjective cannot be copula.
    elsif($node->is_adjective() && !$node->is_pronominal() && $deprel =~ m/^(cop|case|mark)(:|$)/)
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
    # Determiner cannot be advmod, case, mark, cc.
    elsif($node->is_determiner() && $deprel =~ m/^(advmod|case|mark|cc)(:|$)/)
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
    # Cardinal numeral cannot be copula.
    elsif($node->is_numeral() && $deprel =~ m/^cop(:|$)/)
    {
        $deprel = 'nummod';
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
    $self->fix_auxiliary_verb($node);
}



#------------------------------------------------------------------------------
# Fix auxiliary verb that should not be auxiliary.
#------------------------------------------------------------------------------
sub fix_auxiliary_verb
{
    my $self = shift;
    my $node = shift;
    if($node->is_verb() && $node->deprel() =~ m/^cop(:|$)/)
    {
        if($node->lemma() !~ m/^(كَان|لَيس)$/)
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
            # We also have to raise conjunctions and punctuation, otherwise we risk nonprojectivities.
            # Noun modifiers remain with the nominal predicate.
            my @children = $pnom->children();
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^(([nc]subj|obj|advmod|discourse|vocative|expl|aux|mark|cc|punct)(:|$)|obl$)/ ||
                   $child->deprel() =~ m/^obl:([a-z]+)$/ && $1 ne 'arg')
                {
                    $child->set_parent($node);
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->iset()->clear('verbtype');
            $node->set_tag('VERB');
        }
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
