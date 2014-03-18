package Treex::Block::HamleDT::EN::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

###!!! The code from the following blocks should be applied here but has not been applied yet.
#W2A::EN::FixMultiwordPrepAndConj
#W2A::EN::SetAfunAuxCPCoord
#W2A::FixAuxLeaves
#W2A::FixNonleafAuxC

sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone, 'conll');
    $self->distinguish_subordinators_from_prepositions($root);
    $self->fix_annotation_errors($root);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    # Shifting afuns at prepositions and subordinating conjunctions must be done after coordinations are solved
    # and with special care at places where prepositions and coordinations interact.
    $self->process_prep_sub_arg_cloud($root);
    $self->raise_subordinating_conjunctions($root);
    $self->fix_auxiliary_verbs($root);
    $self->check_afuns($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# There is no good documentation of the tags used in CoNLL 2007 English data.
# Something can be found in Richard Johansson, Pierre Nugues: Extended Constituent-to-Dependency Conversion for English, NODALIDA 2007.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my ( $self, $root ) = @_;
    foreach my $node ($root->get_descendants)
    {
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $ppos   = $parent ? $parent->get_iset('pos') : '';
        my $afun = 'NR';
        # Adverbial modifier. Typically realized as adverb or prepositional phrase.
        # Most frequent words: in, to, on, for, at
        # Share prices also/ADV closed lower.
        if($deprel eq 'ADV')
        {
            $afun = 'Adv';
        }
        # Modifier of adjective or adverb. Typically realized as adverb. Example:
        # Most frequent words: million, to, billion, more, as
        # weeks/AMOD ago, very/AMOD unwise
        elsif($deprel eq 'AMOD')
        {
            $afun = 'Adv';
        }
        # Coordinating conjunction that does not head coordination. This could be the first token of the sentence (deficient sentential coordination).
        # Most frequent words: But, And, or, and, not
        elsif($deprel eq 'CC')
        {
            $afun = 'AuxY';
        }
        # Conjunct attached to coordinating conjunction. The head conjunction bears the label of the relation of the whole structure to its parent.
        elsif($deprel eq 'COORD')
        {
            $afun = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # Dependent that does not get any better label. Examples include dependent parts of compound prepositions ("because of", "such as"),
        # members of lists of codes (D., III) etc.
        # Most frequent words: such, of, not, rather, instead
        elsif($deprel eq 'DEP')
        {
            ###!!! Originally I tried AuxY here because it is sometimes interpreted as "anything else".
            ###!!! But it interfered with detection of coordinations, as AuxY nodes were considered delimiters, which was wrong here.
            $afun = 'Atr';
        }
        # Expletive. Typically a verb attached to another verb; sibling of verb1 is the pronoun "it" as substitute subject. Example:
        # It/SBJ is much easier/VMOD to be/EXP second.
        elsif($deprel eq 'EXP')
        {
            ###!!! It would be attached nonprojectively to "it" in PDT, I guess. We should do something about it in structural transformation.
            $afun = 'ExD';
        }
        # Gap, ellipsis. This link connects corresponding sentence elements in coordination with ellipsis.
        # One elided word may cause several GAP links.
        elsif($deprel eq 'GAP')
        {
            $afun = 'ExD';
        }
        # Indirect object. Typically appears next to an OBJ. However, I saw quite a few cases that I would analyze differently.
        # That gave them/IOBJ a sweep/OBJ.
        elsif($deprel eq 'IOBJ')
        {
            $afun = 'Obj';
        }
        # Logical subject in passive clause. Usually a phrase headed by the preposition "by".
        elsif($deprel eq 'LGS')
        {
            $afun = 'Obj';
        }
        # Modifier of noun. Articles, determiners, adjectives, other nouns...
        # Most frequent words: the, of, a, 's, in
        # share/NMOD prices, Hong/NMOD Kong, concern about/NMOD
        elsif($deprel eq 'NMOD')
        {
            $afun = 'Atr';
        }
        # Direct object. Argument of verb.
        # caused pressure/OBJ
        elsif($deprel eq 'OBJ')
        {
            $afun = 'Obj';
        }
        # Punctuation that does not head coordination.
        # Most frequent words: , . `` '' -- :
        elsif($deprel eq 'P')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        # Modifier of preposition. This is the head noun within a prepositional phrase. The preposition bears the label of the relation of the whole structure to its parent.
        # in Sydney/PMOD
        elsif($deprel eq 'PMOD')
        {
            $afun = 'PrepArg';
        }
        # Parenthesis. This is the head of a segment inside brackets.
        # his { Mr. Ortega/PRN 's }
        elsif($deprel eq 'PRN')
        {
            # Some parentheses would be classified as apposition in PDT.
            my @psubtree = $node->get_descendants({add_self => 1, ordered => 1});
            my $lord = $psubtree[0]->ord();
            if($parent->ord() == $lord-1 && $ppos eq 'noun')
            {
                $afun = 'Apposition';
            }
            else
            {
                $afun = 'ExD';
                $node->set_is_parenthesis_root(1);
            }
            ###!!! Special case: ", Mr. Lane said,", "said" is the head and depends on the predicate of what Mr. Lane said.
            ###!!! In PDT, "said" would govern the predicate, which would be labeled Obj. However, if we restructure it here (whenever lemma is "say"), we will introduce nonprojectivity.
            ###!!! There are numerous cases with subordinating conjunctions. Most of them should probably be labeled "Adv".
            ###!!! However, at this moment the subordinating conjunction is not yet the head of the parenthesis. Now it is a child of the head.
        }
        # Particle modifying a verb. Most particles are homonymous with prepositions but their syntactic function is different and so is their POS tag.
        # Most frequent words: up, out, off, down, in
        # setting off/PRT
        elsif($deprel eq 'PRT')
        {
            $afun = 'AuxT';
        }
        # Root of the sentence, main predicate.
        # Coordinating conjunction gets this label in case of coordinate clauses.
        # Most frequent words: said, is, and, was, says
        elsif($deprel eq 'ROOT')
        {
            $afun = 'Pred';
        }
        # Subject. Usually a noun or pronoun.
        # Most frequent words: it, he, that, they, which
        elsif($deprel eq 'SBJ')
        {
            $afun = 'Sb';
        }
        # Temporal expression. This label only applies to names of months that are attached to years.
        # Most frequent words: Nov., Oct., March, October, June
        # for Jan./TMP 1, 1990
        elsif($deprel eq 'TMP')
        {
            $afun = 'Atr';
        }
        # Verb complement. A typical VC node is a content verb whose parent is a finite form of an auxiliary such as will, has, is, would, be.
        # Most frequent words: be, been, have, and, expected
        # is based/VC, before being released/VC, did n't interfere/VC, have n't raised/VC
        elsif($deprel eq 'VC')
        {
            $afun = 'Obj';
        }
        # Modifier of verb. Typically a subordinating conjunction or negation.
        # Most frequent words: to, that, n't, not, as
        # as/VMOD calculated, to/VMOD make, did n't/VMOD
        elsif($deprel eq 'VMOD')
        {
            if($node->form() =~ m/^n[o']t$/i)
            {
                $afun = 'Adv';
            }
            else
            {
                $afun = 'AuxC';
            }
        }
        $node->set_afun($afun);
    }
}



#------------------------------------------------------------------------------
# Corrects known annotation errors in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Nov. 5 and 6
        if($node->conll_deprel() eq 'TMP')
        {
            my $parent = $node->parent();
            my @children = $node->children();
            if($parent && scalar(@children)==1 &&
               scalar($parent->children())==2 &&
               $parent->get_iset('pos') eq 'conj')
            {
                my $child = $children[0];
                my ($the_other) = grep {$_ != $node} ($parent->children());
                if($child->get_iset('pos') eq $the_other->get_iset('pos'))
                {
                    $node->set_parent($parent->parent());
                    $node->set_afun('Atr');
                    $node->set_is_member(0);
                    $parent->set_parent($node);
                    $parent->set_afun('Atr');
                    $parent->set_is_member(0);
                    $child->set_parent($parent);
                    $child->set_afun('CoordArg');
                    $child->wild()->{conjunct} = 1;
                    $the_other->set_afun('CoordArg');
                    $the_other->wild()->{conjunct} = 1;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# The Penn Treebank part-of-speech tagset does not distinguish subordinating
# conjunctions from prepositions. Both get the tag IN. This function will
# distinguish them and adjust Interset POS according to lemma (the Interset
# driver does not have access to lemma and cannot take it into account).
#------------------------------------------------------------------------------
sub distinguish_subordinators_from_prepositions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # We cannot be sure with the following lemmas so we do not change them: as, for, after, since, before, until, in, with, at, like, from, by, on, except, of, out, about, over, worth, lest, without, during, under, 'til
        if($node->get_iset('pos') eq 'prep' &&
           $node->lemma() =~ m/^(that|if|because|while|whether|although|than|though|so|unless|once|whereas|albeit|but)$/)
        {
            $node->set_iset('pos' => 'conj', 'subpos' => 'sub');
            $self->set_pdt_tag($node);
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the English treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    # The Alpino (Dutch) style essentially belongs to the Prague family but it
    # assigns special labels to conjuncts and the function of the whole
    # structure is marked at the coordination head.
    $coordination->detect_alpino($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}



#------------------------------------------------------------------------------
# Adapted from Martin Popel's W2A::EN::RehangConllToPdtStyle.
#------------------------------------------------------------------------------
sub fix_auxiliary_verbs
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $raise = 0;
        my @eparents = $node->get_eparents();
        if(scalar(@eparents)>=1)
        {
            my $eparent = $eparents[0];
            my $eplemma = $eparent->lemma();
            # We want to switch the auxiliary verb "be", e.g.:
            # What are you doing(deprel=VC, tag=VBG, orig_parent=are)
            # It was done(deprel=VC, tag=VBN, orig_parent=was)
            # but not:
            # According(deprel=ADV, parent=is) to me, it is bad.
            # It has solved(tag=VBN, orig_parent=has) our problems.
            if($eplemma =~ m/^(be|have)$/ && $node->get_iset('pos') eq 'verb' && $node->get_iset('verbform') eq 'part')
            {
                $raise = 1;
            }
            # It will solve(tag=VB, orig_parent=will) our problems.
            elsif($eplemma eq 'will' && $node->get_iset('pos') eq 'verb')
            {
                $raise = 1;
            }
            # It did not solve(tag=VB/VBP, orig_parent=did) anything.
            # The people he does know(tag=VB/VBP, orig_parent=does) are rich.
            elsif($eplemma eq 'do' && $node->get_iset('pos') eq 'verb' && $node->get_iset('verbform') ne 'part')
            {
                $raise = 1;
            }
        }
        if($raise)
        {
            ###!!! Bacha! Je to efektivní rodič, ne nutně topologický rodič, takže převěšování nebude taková sranda!
            ###!!! Správně bychom tady měli pracovat s objekty Cloud a Coordination! Místo toho zatím předpokládáme, že koordinace jsou převěšeny po pražsku.
            if($node->is_member())
            {
                my $coord_head = $node->get_parent();
                my $eparent = $coord_head->get_parent();
                my $grandparent = $eparent->get_parent();
                if($grandparent)
                {
                    $coord_head->set_parent($grandparent);
                    $eparent->set_parent($coord_head);
                    my @epchildren = $eparent->get_children();
                    for my $child (@epchildren)
                    {
                        $child->set_parent($coord_head);
                    }
                }
            }
            else
            {
                my $parent = $node->get_parent();
                my $grandparent = $parent->get_parent();
                if($parent->is_member())
                {
                    $parent->set_is_member(0);
                    $node->set_is_member(1);
                }
                $node->set_parent($grandparent);
                my @be_children = $parent->get_children();
                for my $child (@be_children)
                {
                    $child->set_parent($node);
                }
                $parent->set_parent($node);
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::EN::Harmonize

Converts English trees from the annotation style of CoNLL 2007 (dependency
conversion of Penn Treebank) to the HamleDT (Prague) style.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
