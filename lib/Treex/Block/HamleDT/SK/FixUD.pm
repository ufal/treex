package Treex::Block::HamleDT::SK::FixUD;
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
    # Abbreviations have X instead of the UPOS tag of the unabbreviated word.
    # Try to fix at least some occurrences.
    if($node->is_abbreviation() && $iset->pos() eq '')
    {
        # If all letters are uppercase, assume it is an acronym of a named entity.
        if(uc($node->form()) eq $node->form())
        {
            $node->set_tag('PROPN');
            $iset->add('pos' => 'noun', 'nountype' => 'prop');
            if($deprel =~ m/^advmod(:|$)/)
            {
                $deprel = 'obl';
                $node->set_deprel($deprel);
            }
        }
        elsif($lform =~ m/^(cca|napr|resp)$/)
        {
            $iset->add('pos' => 'adv');
        }
    }
    # "si" is the 2nd person present form of "byť" ("to be"), or the dative form of the reflexive clitic.
    elsif($lform eq 'si' && $deprel =~ m/^(aux|cop)(:|$)/)
    {
        $lemma = 'byť';
        $node->set_lemma($lemma);
        $node->set_tag('AUX');
        $iset->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'aspect' => 'imp', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'number' => 'sing', 'person' => '2', 'polarity' => 'pos'});
    }
    # Typo: "so" instead of "som".
    elsif($lform eq 'so' && $deprel =~ m/^aux(:|$)/ && $node->parent()->is_participle())
    {
        $lemma = 'byť';
        $node->set_lemma($lemma);
        $node->set_tag('AUX');
        $iset->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'aspect' => 'imp', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'number' => 'sing', 'person' => '1', 'polarity' => 'pos', 'typo' => 'yes'});
    }
    # "ako" can be adverb ("how") or subordinating conjunction ("as, like").
    # If it is tagged SCONJ but attached as advmod, the UPOS should be changed
    # to ADV.
    elsif($lform =~ m/^(ako|čo|čím|tým)$/ && $node->is_conjunction() && $deprel =~ m/^advmod(:|$)/)
    {
        $node->set_tag('ADV');
        $iset->set_hash({'pos' => 'adv', 'prontype' => $lform eq 'tým' ? 'dem' : 'int|rel'});
    }
    # "že" is attached as advmod in "Že ste už o mne počuli?" but we will re-attach it as mark.
    elsif($lform =~ m/^(že|akoby|keby)$/ && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'mark';
        $node->set_deprel($deprel);
    }
    # "čo" is not a pronoun but a subordinator in sentences like
    # "Po tom, čo boli počty zredukované..."
    elsif($lform =~ m/^(čo)$/ && $deprel =~ m/^mark(:|$)/)
    {
        $node->set_tag('SCONJ');
        $iset->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
    }
    # "I" can be the conjunction "i", capitalized, or it can be the Roman numeral 1.
    # If it appears at the beginning of the sentence and is attached as advmod:emph or cc,
    # we will assume that it is a conjunction (there is at least one case where it
    # is wrongly tagged NUM).
    elsif($lform eq 'i' && $node->ord() == 1 && $deprel =~ m/^(advmod|cc)(:|$)/)
    {
        $iset->set_hash({'pos' => 'conj', 'conjtype' => 'coor'});
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
    # These are symbols, not punctuation.
    elsif($lform =~ m/^[<>]$/)
    {
        $iset->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
}



#------------------------------------------------------------------------------
# Fixes dependency relation labels and/or topology of the tree.
#------------------------------------------------------------------------------
sub fix_constructions
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    # There are a few right-to-left appositions that resulted from transforming
    # copula-like constructions with punctuation (":") instead of the copula.
    # Each of them would probably deserve a different analysis but at present
    # we do not care too much and make them 'parataxis' (they occur in nonverbal
    # sentences or segments).
    if($deprel =~ m/^appos(:|$)/ && $node->ord() < $parent->ord())
    {
        $deprel = 'parataxis';
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
    # Reflexive "sa" should not be attached as 'mark' or 'aux'.
    elsif($node->form() =~ m/^(sa)$/i && $node->is_pronoun() && $deprel =~ m/^(mark|aux)(:|$)/)
    {
        $deprel = 'expl:pv';
        $node->set_deprel($deprel);
    }
    # An adverb should not depend on a copula but on the nominal part of the
    # predicate. Example: "Také vakovlk je, respektive před vyhubením byl, ..."
    elsif($node->is_adverb() && $node->deprel() =~ m/^advmod(:|$)/ &&
          $parent->deprel() =~ m/^cop(:|$)/)
    {
        $parent = $parent->parent();
        $node->set_parent($parent);
    }
    # Slovak "a to" ("viz.") is a multi-word conjunction. In the original
    # treebank, multiple attachment options occur:
    # 1. "a" is attached to "to" as 'cc'.
    # 2. both words are attached as siblings (relations 'cc').
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
    # The expression "více než" ("more than") functions as an adverb.
    elsif(lc($node->form()) eq 'než' && $parent->ord() == $node->ord()-1 &&
          lc($parent->form()) eq 'více')
    {
        $deprel = 'fixed';
        $node->set_deprel($deprel);
        $parent->set_deprel('advmod');
    }
    # "rozuměj" (imperative of "understand") is a verb but attached as 'cc'.
    # We will not keep the parallelism to "to jest" here. We will make it a parataxis.
    # Similar: "míněno" (ADJ, passive participle of "mínit")
    elsif($node->form() =~ m/^(rozuměj|dejme|míněno|počínaje|řekněme|říkajíc|srov(nej)?|víte|event)$/i && $deprel =~ m/^(cc|advmod|mark)(:|$)/)
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
    # The colon between two numbers is probably a division symbol, not punctuation.
    elsif($node->form() =~ m/^[+\-:]$/ && !$parent->is_root() && $parent->form() =~ m/^\d+(\.\d+)?$/ &&
          $node->ord() > $parent->ord() &&
          scalar($node->children()) > 0 &&
          (any {$_->form() =~ m/^\d+(\.\d+)?$/} ($node->children())))
    {
        # The node is currently probably tagged as punctuation but it should be a symbol.
        $node->set_tag('SYM');
        $node->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        # The punct relation should no longer be used.
        # We could treat the operator as a predicate and make it a head, with
        # its arguments attached as dependents. However, it is not clear what
        # their relation should be in linguistic terms. Therefore we simply resort
        # to a flat structure.
        $node->set_deprel('flat');
        foreach my $child ($node->children())
        {
            if($child->ord() > $parent->ord())
            {
                $child->set_parent($parent);
                $child->set_deprel($child->is_punctuation() ? 'punct' : 'flat');
            }
        }
    }
    # A star followed by a year is not punctuation. It is a symbol meaning "born in".
    # Especially if enclosed in parentheses.
    elsif($node->form() eq '*' &&
          (defined($node->get_right_neighbor()) && $node->get_right_neighbor()->ord() == $node->ord()+1 && $node->get_right_neighbor()->form() =~ m/^[12]?\d\d\d$/ ||
           scalar($node->children())==1 && ($node->children())[0]->ord() == $node->ord()+1 && ($node->children())[0]->form() =~ m/^[12]?\d\d\d$/ ||
           !$parent->is_root() && $parent->ord() == $node->ord()+1 && $parent->form() =~ m/^[12]?\d\d\d$/))
    {
        $node->set_tag('SYM');
        $node->iset()->set_hash({'pos' => 'sym'});
        $deprel = 'parataxis' unless($deprel =~ m/^root(:|$)/);
        $node->set_deprel($deprel);
        my $year = $node->get_right_neighbor();
        if(defined($year) && $year->form() =~ m/^[12]?\d\d\d$/)
        {
            $year->set_parent($node);
        }
        elsif(!$parent->is_root() && $parent->form() =~ m/^[12]?\d\d\d$/)
        {
            $year = $parent;
            $parent = $year->parent();
            $node->set_parent($parent);
            if($year->deprel() =~ m/^root(:|$)/)
            {
                $deprel = $year->deprel();
                $node->set_deprel($deprel);
            }
            $year->set_parent($node);
            $year->set_deprel('obl');
            # There may be parentheses attached to the year. Reattach them to me.
            foreach my $child ($year->children())
            {
                $child->set_parent($node);
            }
        }
        my @children = grep {$_->form() =~ m/^[12]?\d\d\d$/} ($node->children());
        if(scalar(@children)>0)
        {
            $year = $children[0];
            $year->set_deprel('obl');
        }
        # If there are parentheses, make sure they are attached to the star as well.
        my $l = $node->get_left_neighbor();
        my $r = $node->get_right_neighbor();
        if(defined($l) && defined($r) && $l->form() eq '(' && $r->form() eq ')')
        {
            $l->set_parent($node);
            $r->set_parent($node);
        }
    }
    # "..." is sometimes attached as the last conjunct in coordination.
    # (It is three tokens, each period separate.)
    # Comma is sometimes attached as a conjunct. It is a result of ExD_Co in
    # the original treebank.
    elsif($node->is_punctuation() && $deprel =~ m/^conj(:|$)/ &&
          $node->is_leaf())
    {
        $deprel = 'punct';
        $node->set_deprel($deprel);
    }
    # Hyphen is sometimes used as a predicate similar to a copula, but not with
    # Pnom. Rather its children are subject and object. Sometimes there is
    # ellipsis and one of the children comes out as 'dep'.
    # "celková škoda - 1000 korun"
    # "týden pro dospělého - 1400 korun, pro dítě do deseti let - 700 korun"
    # We do not know what to do if there fewer than 2 children. However, there
    # can be more if the entire expression is enclosed in parentheses.
    elsif($node->form() =~ m/^[-:]$/ && scalar($node->children()) >= 2)
    {
        my @children = $node->get_children({'ordered' => 1});
        my @punctchildren = grep {$_->deprel() =~ m/^punct(:|$)/} (@children);
        my @argchildren = grep {$_->deprel() !~ m/^punct(:|$)/} (@children);
        if(scalar(@argchildren) == 0)
        {
            # There are 2 or more children and all are punctuation.
            # Silently exit this branch. This will be solved elsewhere.
        }
        elsif(scalar(@argchildren) == 2)
        {
            # Assume that the hyphen is acting like a copula. If we are lucky,
            # one of the children is labeled as a subject. The other will be
            # object or oblique and that is the one we will treat as predicate.
            # If we are unlucky (e.g. because of ellipsis), no child is labeled
            # as subject. Then we take the first one.
            my $s = $argchildren[0];
            my $p = $argchildren[1];
            if($p->deprel() =~ m/subj/ && $s->deprel() !~ m/subj/)
            {
                $s = $argchildren[1];
                $p = $argchildren[0];
            }
            $p->set_parent($parent);
            $deprel = 'parataxis' if($deprel =~ m/^punct(:|$)/);
            $p->set_deprel($deprel);
            $s->set_parent($p);
            foreach my $punct (@punctchildren)
            {
                $punct->set_parent($p);
            }
            $parent = $p;
            $deprel = 'punct';
            $node->set_parent($parent);
            $node->set_deprel($deprel);
        }
        else # more than two non-punctuation children
        {
            # Examples (head words of children in parentheses):
            # 'Náměstek ministra podnikatelům - daňové nedoplatky dosahují miliard' (Náměstek podnikatelům dosahují)
            # 'Týden pro dospělého - 1400 korun , pro dítě do deseti let - 700 korun .' (Týden korun -)
            # 'V " supertermínech " jako je Silvestr - 20 německých marek za osobu , jinak 12 marek , případně v přepočtu na koruny .' (supertermínech marek osobu jinak)
            # 'Dnes v listě Neobyčejně obyčejné příběhy - portrét režiséra Karla Kachyni' (Dnes listě portrét)
            # 'Brankáři s nulou : Hlinka ( Vítkovice ) a Novotný ( Jihlava ) - oba ve 2 . kole .' (Brankáři oba kole)
            # '25 . 2 . 1994 - hebronský masakr ( židovský osadník Baruch Goldstein postřílel při modlitbě tři desítky Arabů ) ;' (2 masakr postřílel)
            ###!!! It is not clear what we should do. For the moment, we just pick the first child as the head.
            my $p = shift(@argchildren);
            $p->set_parent($parent);
            $deprel = 'parataxis' if($deprel =~ m/^punct(:|$)/);
            $p->set_deprel($deprel);
            foreach my $arg (@argchildren)
            {
                $arg->set_parent($p);
            }
            foreach my $punct (@punctchildren)
            {
                $punct->set_parent($p);
            }
            $parent = $p;
            $deprel = 'punct';
            $node->set_parent($parent);
            $node->set_deprel($deprel);
        }
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
    if($node->deprel() =~ m/^cop(:|$)/ && $node->lemma() !~ m/^(byť|bývať|mať|stať)$/)
    {
        log_warn("Spona má lemma '".$node->lemma()."' a značku '".$node->tag()."'.");
    }
    if($node->tag() eq 'AUX')
    {
        if($node->deprel() =~ m/^cop(:|$)/ &&
           $node->lemma() =~ m/^(mať|stať)$/)
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
    elsif($node->deprel() =~ m/^cop(:|$)/ && $node->lemma() =~ m/^(mať)$/)
    {
        log_warn("Deprel is 'cop' and lemma is 'mať' but tag is ".$node->tag());
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
    # "prosím vás" ("I ask you"): "vás" should be "obj", not "cc".
    if(lc($node->form()) eq 'vás' && !$node->is_root() && lc($node->parent()->form()) eq 'prosím')
    {
        $node->set_deprel('obj');
    }
    # "kategorii ** nebo ***"
    elsif($spanstring eq 'kategorii * * nebo * * *')
    {
        my @subtree = $self->get_node_subtree($node);
        log_fatal('Something is wrong') if(scalar(@subtree)!=7);
        # The stars are symbols but not punctuation.
        foreach my $istar (1, 2, 4, 5, 6)
        {
            $subtree[$istar]->set_tag('SYM');
            $subtree[$istar]->iset()->set_hash({'pos' => 'sym'});
        }
        $subtree[3]->set_parent($subtree[4]);
        $subtree[3]->set_deprel('cc');
        $subtree[4]->set_parent($subtree[1]);
        $subtree[4]->set_deprel('conj');
        $subtree[1]->set_parent($node); # i.e. $subtree[0]
        $subtree[1]->set_deprel('nmod');
        $subtree[2]->set_parent($subtree[1]);
        $subtree[2]->set_deprel('flat');
        $subtree[5]->set_parent($subtree[4]);
        $subtree[5]->set_deprel('flat');
        $subtree[6]->set_parent($subtree[4]);
        $subtree[6]->set_deprel('flat');
    }
    # "m.j." ("among others"): error: "j." is interpreted as "je" ("is") instead of "jiné" ("others")
    elsif($spanstring eq 'm . j .')
    {
        my @subtree = $self->get_node_subtree($node);
        $node->set_lemma('jiný');
        $node->set_tag('ADJ');
        $node->iset()->set_hash({'pos' => 'adj', 'gender' => 'neut', 'number' => 'sing', 'case' => 'acc', 'degree' => 'pos', 'polarity' => 'pos', 'abbr' => 'yes'});
        my $parent = $node->parent();
        $subtree[0]->set_parent($parent);
        $subtree[0]->set_deprel('advmod');
        $subtree[1]->set_parent($subtree[0]);
        $subtree[1]->set_deprel('punct');
        $subtree[2]->set_parent($subtree[0]);
        $subtree[2]->set_deprel('fixed');
        $subtree[3]->set_parent($subtree[2]);
        $subtree[3]->set_deprel('punct');
    }
    # "hlavního lékaře", de facto ministra zdravotnictví, ... "de facto" is split.
    elsif($spanstring eq '" hlavního lékaře " , de facto ministra zdravotnictví ,')
    {
        my @subtree = $self->get_node_subtree($node);
        my $de = $subtree[5];
        my $facto = $subtree[6];
        my $ministra = $subtree[7];
        $de->set_parent($ministra);
        $de->set_deprel('advmod:emph');
        $facto->set_parent($de);
        $facto->set_deprel('fixed');
    }
    # "z Jensen Beach"
    elsif($spanstring eq 'z Jensen Beach na Floridě')
    {
        my @subtree = $self->get_node_subtree($node);
        # Jensen is tagged ADJ and currently attached as 'cc'. We change it to
        # 'amod' now, although in all such cases, both English words should be
        # PROPN in Czech, Jensen should be the head and Beach should be attached
        # as 'flat:name'.
        $subtree[1]->set_deprel('amod');
    }
    # "Gottlieb and Pearson"
    elsif($spanstring eq 'Gottlieb and Pearson')
    {
        my @subtree = $self->get_node_subtree($node);
        # Gottlieb is currently 'cc' on Pearson.
        $subtree[0]->set_parent($node->parent());
        $subtree[0]->set_deprel($node->deprel());
        $subtree[2]->set_parent($subtree[0]);
        $subtree[2]->set_deprel('conj');
        $subtree[1]->set_parent($subtree[2]);
        $subtree[1]->set_deprel('cc');
    }
    # Too many vertical bars attached to the root. The Punctuation block could
    # not deal with it.
    elsif($spanstring eq '| Nabídky kurzů , školení , | | seminářů a rekvalifikací | | zveřejňujeme na straně 15 . |')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[5]->set_parent($subtree[8]);
        $subtree[6]->set_parent($subtree[8]);
    }
    # "Jenomže všechno má své kdyby." ... "kdyby" is mentioned, not used.
    elsif($spanstring eq 'Jenomže všechno má své když by .')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[4]->set_parent($subtree[2]);
        $subtree[4]->set_deprel('obj');
        # Maybe it would be better not to split "kdyby" to "když by" in this case.
        # But the splitting block cannot detect such cases. And what UPOS tag would we use? NOUN?
        $subtree[5]->set_parent($subtree[4]);
        $subtree[5]->set_deprel('conj');
    }
    # "podle § 209 tr. zák." ... "§" is strangely mis-coded as "|"
    elsif($spanstring eq 'podle | 209 tr . zák .')
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        my $deprel = 'obl';
        $subtree[1]->set_lemma('§');
        $subtree[1]->set_tag('SYM');
        $subtree[1]->iset()->set_hash({'pos' => 'sym', 'typo' => 'yes'});
        $subtree[1]->set_parent($parent);
        $subtree[1]->set_deprel($deprel);
        $subtree[0]->set_parent($subtree[1]);
        $subtree[0]->set_deprel('case');
        $subtree[5]->set_parent($subtree[1]);
        # The rest seems to be annotated correctly.
    }
    # MIROSLAV MACEK
    elsif($node->form() eq 'MIROSLAV' && $node->deprel() =~ m/^punct(:|$)/)
    {
        $node->set_deprel('parataxis');
    }
    # "Žvásty,"
    elsif($spanstring =~ m/^Žvásty , "/i) #"
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_parent($subtree[0]);
        $subtree[1]->set_deprel('punct');
        $subtree[2]->set_parent($subtree[0]);
        $subtree[2]->set_deprel('punct');
    }
    # "Tenis ad-Řím"
    # In this case I really do not know what it is supposed to mean.
    elsif($spanstring =~ m/^Tenis ad - Řím$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('dep');
    }
    # Pokud jsme ..., tak
    elsif($spanstring =~ m/^pokud tak$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[1]->ord() >= $subtree[0]->ord()+4)
        {
            $subtree[1]->set_parent($subtree[0]->parent()->parent());
            $subtree[1]->set_deprel('advmod');
        }
    }
    # "SÁZKA 5 ZE 40: 9, 11, 23, 36, 40, dodatkové číslo: 1."
    elsif($spanstring =~ m/^SÁZKA 5 ZE 40 : \d+ , \d+ , \d+ , \d+ , \d+ , dodatkové číslo : \d+ \.$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        # "ze 40" depends on "5" but it is not 'compound'
        $subtree[3]->set_deprel('nmod');
        # The first number after the colon depends on "sázka".
        $subtree[5]->set_parent($subtree[0]);
        $subtree[5]->set_deprel('appos');
        # All other numbers are conjuncts.
        for(my $i = 6; $i <= 14; $i += 2)
        {
            # Punctuation depends on the following conjunct.
            my $fc = $i==14 ? $i+2 : $i+1;
            $subtree[$i]->set_parent($subtree[$fc]);
            # Conjunct depends on the first conjunct.
            $subtree[$fc]->set_parent($subtree[5]);
            $subtree[$fc]->set_deprel('conj');
        }
    }
    # "Kainarova koleda Vracaja sa dom"
    elsif($node->form() eq 'Vracaja' && $node->deprel() =~ m/^advmod(:|$)/)
    {
        # This is not a typical example of an adnominal clause.
        # But we cannot use anything else because the head node is a verb.
        $node->set_deprel('acl');
    }
    # "Žili byli v zemi české..."
    elsif($spanstring =~ m/^Žili byli/ && $node->form() eq 'byli')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[0]->set_parent($node->get_root());
        $subtree[0]->set_deprel('root');
        $subtree[1]->set_parent($subtree[0]);
        $subtree[1]->set_tag('AUX');
        $subtree[1]->iset()->set('verbtype' => 'aux');
        $subtree[1]->set_deprel('aux');
        foreach my $child ($subtree[1]->children())
        {
            $child->set_parent($subtree[0]);
        }
    }
    elsif($spanstring =~ m/^, tj \. bude - li zákon odmítnut/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('cc');
        $subtree[2]->set_parent($subtree[1]);
        $subtree[5]->set_parent($subtree[7]);
        $subtree[5]->set_deprel('mark');
    }
    elsif($spanstring =~ m/^, co je a co není rovný přístup ke vzdělání$/i)
    {
        # In the original treebank, "co" is subject and "rovný přístup ke vzdělání" is predicate, not vice versa.
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        my @subtree = $self->get_node_subtree($node);
        # The first conjunct lacks the nominal predicate. Promote the copula.
        $subtree[2]->set_parent($parent);
        $subtree[2]->set_deprel($deprel);
        $subtree[0]->set_parent($subtree[2]);
        # Attach the nominal predicate as the second conjunct.
        $subtree[7]->set_parent($subtree[2]);
        $subtree[7]->set_deprel('conj');
        $subtree[3]->set_parent($subtree[7]);
        $subtree[4]->set_parent($subtree[7]);
        $subtree[5]->set_parent($subtree[7]);
        $subtree[5]->set_deprel('cop');
        # Since "není" originally did not have the 'cop' relation, it was probably not converted from VERB to AUX.
        $subtree[5]->set_tag('AUX');
        $subtree[5]->iset()->set('verbtype' => 'aux');
    }
    elsif($spanstring =~ m/^Karoshi [-:] přece jen smrt z přepracování \?/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[4]->set_parent($subtree[0]);
        $subtree[4]->set_deprel('parataxis');
        $subtree[1]->set_parent($subtree[4]);
        $subtree[2]->set_parent($subtree[4]);
    }
    elsif($spanstring =~ m/^, je - li rho > rho _ c ,$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        $subtree[5]->set_parent($parent);
        $subtree[5]->set_deprel($deprel);
        $subtree[5]->set_tag('SYM');
        $subtree[5]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[0]->set_parent($subtree[5]);
        $subtree[1]->set_parent($subtree[5]);
        $subtree[1]->set_tag('AUX');
        $subtree[1]->iset()->set('verbtype' => 'aux');
        $subtree[1]->set_deprel('cop');
        $subtree[2]->set_parent($subtree[5]);
        $subtree[3]->set_parent($subtree[5]);
        $subtree[4]->set_parent($subtree[5]);
        $subtree[9]->set_parent($subtree[5]);
    }
    elsif($spanstring =~ m/^je - li rho < rho _ c ,$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        my $deprel = $node->deprel();
        $subtree[4]->set_parent($parent);
        $subtree[4]->set_deprel($deprel);
        $subtree[4]->set_tag('SYM');
        $subtree[4]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[0]->set_parent($subtree[4]);
        $subtree[0]->set_tag('AUX');
        $subtree[0]->iset()->set('verbtype' => 'aux');
        $subtree[0]->set_deprel('cop');
        $subtree[1]->set_parent($subtree[4]);
        $subtree[2]->set_parent($subtree[4]);
        $subtree[3]->set_parent($subtree[4]);
        $subtree[8]->set_parent($subtree[4]);
    }
    elsif($spanstring =~ m/^(- (\d+|p|C)|< pc|\. (q|r))$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        # In cases where "-" acts as the minus operator, it is attached to the
        # first operand and the second operand is attached to it. We must check
        # the topology, otherwise this block would transform all occurrences of
        # a hyphen between two numbers.
        if($subtree[0]->parent()->ord() <= $subtree[0]->ord()-1 &&
           $subtree[1]->parent()->ord() == $subtree[0]->ord())
        {
            $subtree[0]->set_tag('SYM');
            $subtree[0]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
            $subtree[0]->set_deprel('flat');
        }
    }
    elsif($spanstring =~ m/^\. \( [pq] - \d+ \)$/)
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[0]->parent()->ord() < $subtree[0]->ord())
        {
            $subtree[0]->set_tag('SYM');
            $subtree[0]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
            $subtree[0]->set_deprel('flat');
        }
    }
    elsif($spanstring =~ m/^\d+ \. \d+/)
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[1]->parent() == $subtree[0] &&
           $subtree[2]->parent() == $subtree[1])
        {
            $subtree[1]->set_tag('SYM');
            $subtree[1]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
            $subtree[1]->set_deprel('flat');
        }
    }
    elsif($spanstring =~ m/^i \. j - \d+$/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_tag('SYM');
        $subtree[1]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[1]->set_deprel('flat');
        $subtree[3]->set_tag('SYM');
        $subtree[3]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[3]->set_deprel('flat');
    }
    elsif($spanstring =~ m/^Kdykoliv p > pc ,$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[2]->set_tag('SYM');
        $subtree[2]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[2]->set_deprel('advcl');
    }
    elsif($spanstring =~ m/^" Není možné , aby by sin \( x \) > 1 "$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[10]->set_tag('SYM');
        $subtree[10]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
        $subtree[10]->set_deprel('csubj');
        $subtree[10]->set_parent($subtree[2]);
        for(my $i = 3; $i <= 5; $i++)
        {
            $subtree[$i]->set_parent($subtree[10]);
        }
    }
    elsif($spanstring =~ m/^\. \. \.$/)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        unless($parent->is_root())
        {
            foreach my $node (@subtree)
            {
                $node->set_parent($parent);
                $node->set_deprel('punct');
            }
        }
    }
    elsif($spanstring =~ m/^, \.$/)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        unless($parent->is_root())
        {
            foreach my $node (@subtree)
            {
                $node->set_parent($parent);
                $node->set_deprel('punct');
            }
        }
    }
    # degrees of Celsius
    elsif($spanstring eq 'o C')
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[0]->deprel() =~ m/^punct(:|$)/)
        {
            $subtree[0]->set_tag('SYM');
            $subtree[0]->iset()->set_hash({'pos' => 'sym', 'conjtype' => 'oper'});
            $subtree[0]->set_deprel('flat');
            $subtree[1]->set_deprel('nmod');
        }
    }
    elsif($spanstring eq 'při teplotě -103 C')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[3]->set_parent($subtree[1]);
        $subtree[2]->set_parent($subtree[3]);
        $subtree[2]->set_deprel('nummod:gov');
        $subtree[2]->set_tag('NUM');
        $subtree[2]->iset()->set_hash({'pos' => 'num', 'numform' => 'digit', 'numtype' => 'card'});
    }
    # "v jejich čele"
    elsif($spanstring eq 'v jejich čele')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[2]->set_deprel('obl');
    }
    # "a jak"
    elsif($spanstring =~ m/^a jak$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        # Avoid messing up coordination "kdy a jak". Require that the parent is to the right.
        if($parent->ord() > $node->ord())
        {
            $subtree[0]->set_parent($parent);
            $subtree[0]->set_deprel('cc');
            $subtree[1]->set_parent($parent);
            $subtree[1]->set_deprel($subtree[1]->is_adverb() ? 'advmod' : 'mark');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::SK::FixUD

Slovak-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
