package Treex::Block::HamleDT::CS::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::SplitFusedWords';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        $self->fix_morphology($node);
        $self->classify_numerals($node);
    }
    # Do not call syntactic fixes from the previous loop. First make sure that
    # all nodes have correct morphology, then do syntax (so that you can rely
    # on the morphology you see at the parent node).
    foreach my $node (@nodes)
    {
        $self->fix_constructions($node);
    }
    $self->fix_jak_znamo($root);
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
    # If "to znamená" is abbreviated and tokenized as "tzn .", PDT tags it as
    # a verb but analyzes it syntactically as a conjunction. We will re-tag it
    # as a conjunction.
    elsif($lform eq 'tzn' && $iset->is_verb())
    {
        $iset->set_hash({'pos' => 'conj', 'conjtype' => 'coor', 'abbr' => 'yes'});
    }
    # The word "plus" can be a noun or a mathematical conjunction. If it is
    # attached as 'cc', it should be conjunction.
    elsif($lform eq 'plus' && $deprel =~ m/^cc(:|$)/)
    {
        $iset->set_hash({'pos' => 'conj', 'conjtype' => 'oper'});
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
}



#------------------------------------------------------------------------------
# Splits numeral types that have the same tag in the PDT tagset and the
# Interset decoder cannot distinguish them because it does not see the word
# forms. NOTE: We may want to move this function to Prague harmonization.
#------------------------------------------------------------------------------
sub classify_numerals
{
    my $self  = shift;
    my $node  = shift;
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



#------------------------------------------------------------------------------
# Converts dependency relations from UD v1 to v2.
#------------------------------------------------------------------------------
sub fix_constructions
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    # The noun "pravda" ("truth") used as sentence-initial particle is attached
    # as 'cc' but should be attached as 'discourse'.
    if(lc($node->form()) eq 'pravda' && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
    }
    # The abbreviation "tzv" ("takzvaný" = "so called") is an adjective.
    # However, it is sometimes confused with "tzn" (see below) and attached as
    # 'cc'.
    elsif(lc($node->form()) eq 'tzv' && $node->is_adjective() && $parent->ord() > $node->ord())
    {
        $deprel = 'amod';
        $node->set_deprel($deprel);
    }
    # The abbreviation "aj" ("a jiné" = "and other") is tagged as an adjective
    # but sometimes it is attached to the last conjunct as 'cc'. We should re-
    # attach it as a conjunct. We may also consider splitting it as a multi-
    # word token.
    elsif(lc($node->form()) eq 'aj' && $node->is_adjective() && $deprel =~ m/^cc(:|$)/)
    {
        my $first_conjunct = $parent->deprel() =~ m/^conj(:|$)/ ? $parent->parent() : $parent;
        # If it is the first conjunct, it lies on our left hand. If it does not,
        # there is something weird and wrong.
        if($first_conjunct->ord() < $node->ord())
        {
            $parent = $first_conjunct;
            $deprel = 'conj';
            $node->set_parent($parent);
            $node->set_deprel($deprel);
        }
    }
    # The expression "všeho všudy" ("altogether") functions as an adverb.
    elsif(lc($node->form()) eq 'všeho' && $parent->ord() == $node->ord()+1 &&
          lc($parent->form()) eq 'všudy')
    {
        my $grandparent = $parent->parent();
        $deprel = $parent->deprel();
        $node->set_parent($grandparent);
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('fixed');
        $parent = $grandparent;
    }
    # In PDT, the words "dokud" ("while") and "jakoby" ("as if") are sometimes
    # attached as adverbial modifiers although they are conjunctions.
    elsif($node->is_subordinator() && $deprel =~ m/^advmod(:|$)/ && scalar($node->children()) == 0)
    {
        $deprel = 'mark';
        $node->set_deprel($deprel);
    }
    # Czech "a to" ("viz.") is a multi-word conjunction. In PDT it is headed by
    # "to", which is a demonstrative pronoun, not conjunction. Transform it and
    # use the 'fixed' relation.
    elsif(lc($node->form()) eq 'a' && $deprel =~ m/^cc(:|$)/ &&
          $parent->form() =~ m/^(to|sice)$/i && $parent->deprel() =~ m/^(cc|advmod|discourse)(:|$)/ && $parent->ord() > $node->ord())
    {
        my $grandparent = $parent->parent();
        $node->set_parent($grandparent);
        $deprel = 'cc';
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('fixed');
        # These occurrences of "to" should be lemmatized as "to" and tagged 'PART'.
        # However, sometimes they are lemmatized as "ten" and tagged 'DET'.
        $parent->set_lemma('to');
        $parent->set_tag('PART');
        $parent->iset()->set_hash({'pos' => 'part'});
        $parent = $grandparent;
    }
    # Sometimes "to" is already attached to "a", and we only change the relation type.
    elsif(lc($node->form()) =~ m/^(to|sice)$/i && $deprel =~ m/^(cc|advmod|discourse)(:|$)/ &&
          lc($parent->form()) eq 'a' && $parent->ord() == $node->ord()-1)
    {
        $deprel = 'fixed';
        $node->set_deprel($deprel);
        # These occurrences of "to" should be lemmatized as "to" and tagged 'PART'.
        # However, sometimes they are lemmatized as "ten" and tagged 'DET'.
        if(lc($node->form()) eq 'to')
        {
            $node->set_lemma('to');
            $node->set_tag('PART');
            $node->iset()->set_hash({'pos' => 'part'});
        }
    }
    # "a tím i" ("and this way also")
    elsif(lc($node->form()) eq 'tím' && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
    }
    # Occasionally "a" and "to" are attached as siblings rather than one to the other.
    elsif(lc($node->form()) =~ m/^(a)$/ && $deprel =~ m/^cc(:|$)/ &&
          defined($node->get_right_neighbor()) &&
          lc($node->get_right_neighbor()->form()) =~ m/^(to)$/ && $node->get_right_neighbor()->deprel() =~ m/^(cc|advmod|discourse)(:|$)/)
    {
        my $to = $node->get_right_neighbor();
        $to->set_parent($node);
        $to->set_deprel('fixed');
        # These occurrences of "to" should be lemmatized as "to" and tagged 'PART'.
        # However, sometimes they are lemmatized as "ten" and tagged 'DET'.
        $to->set_lemma('to');
        $to->set_tag('PART');
        $to->iset()->set_hash({'pos' => 'part'});
    }
    # Similar: "to jest/to je/to znamená".
    elsif(lc($node->form()) =~ m/^(to)$/ && $deprel =~ m/^cc(:|$)/ &&
          defined($node->get_right_neighbor()) &&
          lc($node->get_right_neighbor()->form()) =~ m/^(je(st)?|znamená)$/ && $node->get_right_neighbor()->deprel() =~ m/^cc(:|$)/)
    {
        my $to = $node->get_right_neighbor();
        $to->set_parent($node);
        $to->set_deprel('fixed');
    }
    # If "to jest" is abbreviated and tokenized as "t . j .", the above branch
    # will not catch it.
    elsif(lc($node->form()) eq 't' && $deprel =~ m/^cc(:|$)/ &&
          scalar($node->get_siblings({'following_only' => 1})) >= 3 &&
          # following_only implies ordered
          lc(($node->get_siblings({'following_only' => 1}))[0]->form()) eq '.' &&
          lc(($node->get_siblings({'following_only' => 1}))[1]->form()) eq 'j' &&
          lc(($node->get_siblings({'following_only' => 1}))[2]->form()) eq '.')
    {
        my @rsiblings = $node->get_siblings({'following_only' => 1});
        $rsiblings[0]->set_parent($node);
        $rsiblings[0]->set_deprel('punct');
        $rsiblings[2]->set_parent($rsiblings[1]);
        $rsiblings[2]->set_deprel('punct');
        $rsiblings[1]->set_parent($node);
        $rsiblings[1]->set_deprel('fixed');
    }
    # "takové přání, jako je svatba" ("such a wish as (is) a wedding")
    elsif($node->lemma() eq 'být' && $deprel =~ m/^cc(:|$)/ &&
          defined($node->get_left_neighbor()) && lc($node->get_left_neighbor()->form()) eq 'jako' &&
          $parent->ord() > $node->ord())
    {
        my $grandparent = $parent->parent();
        # Besides "jako", there might be other left siblings (punctuation).
        foreach my $sibling ($node->get_siblings({'preceding_only' => 1}))
        {
            $sibling->set_parent($node);
        }
        $node->set_parent($grandparent);
        $node->set_deprel($grandparent->iset()->pos() =~ m/^(noun|num|sym)$/ ? 'acl' : 'advcl');
        $deprel = $node->deprel();
        $parent->set_parent($node);
        $parent->set_deprel('nsubj');
        $parent = $grandparent;
    }
    # "rozuměj" (imperative of "understand") is a verb but attached as 'cc'.
    # We will not keep the parallelism to "to jest" here. We will make it a parataxis.
    elsif(lc($node->form()) eq 'rozuměj' && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'parataxis';
        $node->set_deprel($deprel);
    }
    # Interjections showing the attitude to the speaker towards the event should
    # be attached as 'discourse', not as 'advmod'.
    elsif($node->is_interjection() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
    }
    # Sometimes a sequence of punctuation symbols (e.g., "***"), tokenized as
    # one token per symbol, is analyzed as a constituent headed by one of the
    # symbols. In UD, this should not happen unless the dependent symbols are
    # brackets or quotation marks and the head symbol is enclosed by them.
    elsif($node->is_punctuation() && $parent->is_punctuation())
    {
        unless($node->form() =~ m/^[\{\[\("']$/ && $parent->ord() == $node->ord()+1 ||
               $node->form() =~ m/^['"\)\]\}]$/ && $parent->ord() == $node->ord()-1)
        {
            # Find the first ancestor that is not punctuation.
            my $ancestor = $parent;
            # We should never get to the root because we should first find an
            # ancestor whose deprel is 'root'. But let's not rely on the data
            # too much.
            while(!$ancestor->is_root() && $ancestor->deprel() =~ m/^punct(:|$)/)
            {
                $ancestor = $ancestor->parent();
            }
            if(defined($ancestor) && !$ancestor->is_root() && $ancestor->deprel() !~ m/^punct(:|$)/)
            {
                $node->set_parent($ancestor);
                $node->set_deprel('punct');
            }
        }
    }
}



#------------------------------------------------------------------------------
# The two Czech words "jak známo" ("as known") are attached as ExD siblings in
# the Prague style because there is missing copula. However, in UD the nominal
# predicate "známo" is the head.
#------------------------------------------------------------------------------
sub fix_jak_znamo
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<$#nodes; $i++)
    {
        my $n0 = $nodes[$i];
        my $n1 = $nodes[$i+1];
        if(defined($n0->form()) && lc($n0->form()) eq 'jak' &&
           defined($n1->form()) && lc($n1->form()) eq 'známo' &&
           $n0->parent() == $n1->parent())
        {
            $n0->set_parent($n1);
            $n0->set_deprel('mark');
            $n1->set_deprel('advcl') if(!defined($n1->deprel()) || $n1->deprel() eq 'dep');
            # If the expression is delimited by commas, the commas should be attached to "známo".
            if($i>0 && $nodes[$i-1]->parent() == $n1->parent() && defined($nodes[$i-1]->form()) && $nodes[$i-1]->form() =~ m/^[-,]$/)
            {
                $nodes[$i-1]->set_parent($n1);
                $nodes[$i-1]->set_deprel('punct');
            }
            if($i+2<=$#nodes && $nodes[$i+2]->parent() == $n1->parent() && defined($nodes[$i+2]->form()) && $nodes[$i+2]->form() =~ m/^[-,]$/)
            {
                $nodes[$i+2]->set_parent($n1);
                $nodes[$i+2]->set_deprel('punct');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::DE::FixUD

Czech-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
