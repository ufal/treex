package Treex::Block::HamleDT::EN::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::AlpinoToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'en::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->distinguish_subordinators_from_prepositions($root);
    $self->fix_annotation_errors($root);
    # Phrase-based implementation of tree transformations (5.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::AlpinoToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    # "for someone to do something" must be fixed before raising subordinating conjunctions because the procedure assumes the original layout.
    $self->fix_for_someone_to_do_something($root);
    $self->raise_subordinating_conjunctions($root);
    $self->get_or_load_other_block('W2A::EN::FixMultiwordPrepAndConj')->process_atree($root);
    $self->fix_auxiliary_verbs($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# There is no good documentation of the tags used in CoNLL 2007 English data.
# Something can be found in Richard Johansson, Pierre Nugues: Extended Constituent-to-Dependency Conversion for English, NODALIDA 2007.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    foreach my $node ($root->get_descendants)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
#        my $subpos = $node->get_iset('subpos'); # feature deprecated
        my $ppos   = $parent ? $parent->get_iset('pos') : '';
        # Adverbial modifier. Typically realized as adverb or prepositional phrase.
        # Most frequent words: in, to, on, for, at
        # Share prices also/ADV closed lower.
        if($deprel eq 'ADV')
        {
            $deprel = 'Adv';
        }
        # Modifier of adjective or adverb. Typically realized as adverb. Example:
        # Most frequent words: million, to, billion, more, as
        # weeks/AMOD ago, very/AMOD unwise
        elsif($deprel eq 'AMOD')
        {
            # Special case: about 25 %
            # TREE: % ( about/NMOD ( 25/AMOD ) )
            # Here it is a prepositional phrase and we want it to be treated as such.
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Coordinating conjunction that does not head coordination. This could be the first token of the sentence (deficient sentential coordination).
        # Most frequent words: But, And, or, and, not
        elsif($deprel eq 'CC')
        {
            $deprel = 'AuxY';
        }
        # Conjunct attached to coordinating conjunction. The head conjunction bears the label of the relation of the whole structure to its parent.
        elsif($deprel eq 'COORD')
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # Dependent that does not get any better label. Examples include dependent parts of compound prepositions ("because of", "such as"),
        # members of lists of codes (D., III) etc.
        # Most frequent words: such, of, not, rather, instead
        elsif($deprel eq 'DEP')
        {
            ###!!! Originally I tried AuxY here because it is sometimes interpreted as "anything else".
            ###!!! But it interfered with detection of coordinations, as AuxY nodes were considered delimiters, which was wrong here.
            $deprel = 'Atr';
        }
        # Expletive. Typically a verb attached to another verb; sibling of verb1 is the pronoun "it" as substitute subject. Example:
        # It/SBJ is much easier/VMOD to be/EXP second.
        elsif($deprel eq 'EXP')
        {
            ###!!! It would be attached nonprojectively to "it" in PDT, I guess. We should do something about it in structural transformation.
            $deprel = 'ExD';
        }
        # Gap, ellipsis. This link connects corresponding sentence elements in coordination with ellipsis.
        # One elided word may cause several GAP links.
        elsif($deprel eq 'GAP')
        {
            $deprel = 'ExD';
        }
        # Indirect object. Typically appears next to an OBJ. However, I saw quite a few cases that I would analyze differently.
        # That gave them/IOBJ a sweep/OBJ.
        elsif($deprel eq 'IOBJ')
        {
            $deprel = 'Obj';
        }
        # Logical subject in passive clause. Usually a phrase headed by the preposition "by".
        elsif($deprel eq 'LGS')
        {
            $deprel = 'Obj';
        }
        # Modifier of noun. Articles, determiners, adjectives, other nouns...
        # Most frequent words: the, of, a, 's, in
        # share/NMOD prices, Hong/NMOD Kong, concern about/NMOD
        elsif($deprel eq 'NMOD')
        {
            $deprel = 'Atr';
        }
        # Direct object. Argument of verb.
        # caused pressure/OBJ
        elsif($deprel eq 'OBJ')
        {
            $deprel = 'Obj';
        }
        # Punctuation that does not head coordination.
        # Most frequent words: , . `` '' -- :
        elsif($deprel eq 'P')
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
                # There are a few annotation errors where the comma heads a coordination but lacks the function of the coordination towards its parent.
                if (grep {$_->conll_deprel() eq 'COORD'} $node->children())
                {
                    # This is a coordinating comma. Guess what is its relation towards its parent.
                    if ($ppos eq 'noun')
                    {
                        $deprel = 'Atr';
                    }
                    elsif ($ppos eq 'verb' && $parent->lemma() eq 'be')
                    {
                        $deprel = 'Pnom';
                    }
                    else # non-copula verb
                    {
                        $deprel = 'Adv';
                    }
                }
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        # Modifier of preposition. This is the head noun within a prepositional phrase. The preposition bears the label of the relation of the whole structure to its parent.
        # in Sydney/PMOD
        elsif($deprel eq 'PMOD')
        {
            $deprel = 'PrepArg';
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
                $deprel = 'Apposition';
            }
            else
            {
                $deprel = 'ExD';
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
            $deprel = 'AuxT';
        }
        # Root of the sentence, main predicate.
        # Coordinating conjunction gets this label in case of coordinate clauses.
        # Most frequent words: said, is, and, was, says
        elsif($deprel eq 'ROOT')
        {
            $deprel = 'Pred';
        }
        # Subject. Usually a noun or pronoun.
        # Most frequent words: it, he, that, they, which
        elsif($deprel eq 'SBJ')
        {
            $deprel = 'Sb';
        }
        # Temporal expression. This label only applies to names of months that are attached to years.
        # Most frequent words: Nov., Oct., March, October, June
        # for Jan./TMP 1, 1990
        elsif($deprel eq 'TMP')
        {
            $deprel = 'Atr';
        }
        # Verb complement. A typical VC node is a content verb whose parent is a finite form of an auxiliary such as will, has, is, would, be.
        # Most frequent words: be, been, have, and, expected
        # is based/VC, before being released/VC, did n't interfere/VC, have n't raised/VC
        # Note that verbal (infinitive) arguments of some verbs are also labeled VC.
        # These "some" verbs are roughly the modal verbs (tagged MD) with the exception of "ought" and with the addition of "be going to";
        # also note that the auxiliaries for future tense ("will") and conditional ("would") are tagged MD as well:
        # will, would; must, can, could, may, might, shall, should; [be] going [to]
        elsif($deprel eq 'VC')
        {
            if($parent->form() =~ m/^(must|can|could|may|might|shall|should|going)$/i)
            {
                $deprel = 'Obj';
            }
            else
            {
                # The structure will be later changed. This node will become parent and the current parent will become child, labeled AuxV.
                $deprel = 'AuxV';
            }
        }
        # Modifier of verb. Typically a subordinating conjunction or negation.
        # Most frequent words: to, that, n't, not, as
        # as/VMOD calculated, to/VMOD make, did n't/VMOD
        elsif($deprel eq 'VMOD')
        {
            if($node->form() =~ m/^n[o']t$/i)
            {
                $deprel = 'Neg';
            }
            # We must not toggle on coordinating conjunction!
            # That is most likely a coordination of VMOD conjuncts, whose part of speech could be anything!
            elsif($node->is_subordinator() || $node->is_adposition())
            {
                $deprel = 'AuxC';
            }
            elsif($parent->lemma() eq 'be')
            {
                # may ( be/VC ( difficult/VMOD ) )
                $deprel = 'Pnom';
            }
            else ###!!! ??? investigate!
            {
                $deprel = 'Adv';
            }
        }
        $node->set_deprel($deprel);
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
                    $node->set_deprel('Atr');
                    $node->set_is_member(0);
                    $parent->set_parent($node);
                    $parent->set_deprel('Atr');
                    $parent->set_is_member(0);
                    $child->set_parent($parent);
                    $child->set_deprel('CoordArg');
                    $child->wild()->{conjunct} = 1;
                    $the_other->set_deprel('CoordArg');
                    $the_other->wild()->{conjunct} = 1;
                }
            }
        }
        # Non-coordinating non-leaf comma.
        elsif($node->form() eq ',')
        {
            my @children = $node->children();
            if(@children && !grep {$_->conll_deprel() eq 'COORD'} (@children))
            {
                # Reattach all children of the comma to the parent of the comma.
                my $parent = $node->parent();
                foreach my $child (@children)
                {
                    $child->set_parent($parent);
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
        # Sometimes the borderline between prepositions and conjunctions is fuzzy (that's why they gave them one tag after all).
        # We cannot be sure with the following lemmas (all of them occurred with the VMOD deprel tag) so we do not change them:
        # for, after, since, before, until, in, with, at, like, from, by, on, except, of, out, about, over, worth, lest, without, during, under, 'til
        my $lemma = $node->lemma();
        if($node->is_adposition() &&
           ($lemma =~ m/^(that|if|because|while|whether|although|than|though|so|unless|once|whereas|albeit|but|as)$/ ||
            $node->conll_deprel() eq 'VMOD' && $lemma =~ m/^(before|after|since|until|except)$/))
        {
            $node->set_iset('pos' => 'conj', 'conjtype' => 'sub');
            $self->set_pdt_tag($node);
        }
    }
}



#------------------------------------------------------------------------------
# Construction type: they have been desperate for the US to rejoin the group
# ORIGINAL TREE: desperate ( rejoin/AMOD ( for/VMOD, US/SBJ, to/VMOD, group/OBJ ) )
# DESIRED TREE: desperate ( to/AuxC ( rejoin/Obj ( for/AuxP ( US/Sb ), group/Obj ) ) )
#------------------------------------------------------------------------------
sub fix_for_someone_to_do_something
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if(lc($node->form()) eq 'for' && $node->is_leaf() && $node->parent()->get_iset('pos') eq 'verb')
        {
            my $verb = $node->parent();
            my @children = $verb->children();
            my ($to) = grep {$_->form() eq 'to'} (@children);
            my $subject = $node->get_right_neighbor();
            ###!!! Pozor, podmět taky může být koordinace, s tím tady zatím nepočítáme!
            if($to && $subject && $subject->deprel() eq 'Sb')
            {
                my $grandparent = $verb->parent();
                $node->set_deprel('AuxP');
                $subject->set_parent($node);
                $to->set_parent($grandparent);
                $to->set_deprel('AuxC');
                $to->set_is_member($verb->is_member());
                $verb->set_parent($to);
                $verb->set_deprel('Obj');
                $verb->set_is_member(undef);
            }
        }
    }
}



#------------------------------------------------------------------------------
# The auxiliary verb "to be" governs the content verb in the input data because
# if one of the two is finite verb, it is the auxiliary. In PDT however, and so
# far also in HamleDT, auxiliaries are attached to content verbs as AuxV:
#
#   přišel jsem domů: přišel/Pred ( jsem/AuxV , domů/Adv )
#   zítra budu vařit: vařit/Pred ( zítra/Adv , budu/AuxV )
#   to bych neřekl: neřekl/Pred ( to/Obj , bych/AuxV )
#   silnice je opravována: opravována/Pred ( silnice/Sb , je/AuxV )
#
# Thus in English, we also want to make the auxiliary verb depend on the main
# verb:
#
#   we are witnessing:
#     INPUT: are ( we/Sb , witnessing/VBG/VC )
#     OUTPUT: witnessing ( we/Sb , are/AuxV )
#   it was done:
#     INPUT: was ( it/Sb , done/VBN/VC )
#     OUTPUT: done ( it/Sb , was/AuxV )
#
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
        my @eparents;
        # Look for constructions we want to change. Note that we also require that the node already is labeled AuxV (original label VC).
        # We do that to distinguish from adjunct clauses.
        if($node->is_verb() && $node->deprel() eq 'AuxV')
        {
            @eparents = $node->get_eparents();
            if(scalar(@eparents)>=1)
            {
                my $eparent = $eparents[0];
                next unless($eparent);
                my $eplemma = $eparent->lemma();
                next unless($eplemma);
                # We want to switch the auxiliary verb "be", e.g.:
                # What are you doing(deprel=VC, tag=VBG, orig_parent=are)
                # It was done(deprel=VC, tag=VBN, orig_parent=was)
                # It has solved(tag=VBN, orig_parent=has) our problems.
                # but not:
                # According(deprel=ADV, parent=is) to me, it is bad.
                if($node->get_iset('verbform') eq 'part' && $eplemma =~ m/^(be|have)$/)
                {
                    $raise = 1;
                }
                # It will solve(tag=VB, orig_parent=will) our problems.
                elsif($eplemma eq 'will')
                {
                    $raise = 1;
                }
                # It did not solve(tag=VB/VBP, orig_parent=did) anything.
                # The people he does know(tag=VB/VBP, orig_parent=does) are rich.
                elsif($node->get_iset('verbform') ne 'part' && $eplemma eq 'do')
                {
                    $raise = 1;
                }
            }
        }
        # Exchange the auxiliary with the main verb if the triggering situation has been identified.
        if($raise)
        {
            ###!!! Bacha! Je to efektivní rodič, ne nutně topologický rodič, takže převěšování nebude taková sranda!
            ###!!! Správně bychom tady měli pracovat s objekty Cloud a Coordination!
            ###!!! Místo toho se zatím koordinacím vyhýbáme a když nějakou spatříme, od převěšování upustíme.
            my $parent = $node->parent();
            unless($node->is_member() || $parent->is_member() || scalar(@eparents)!=1 || $eparents[0]!=$parent)
            {
                my $grandparent = $parent->get_parent();
                $node->set_parent($grandparent);
                $node->set_deprel($parent->deprel());
                my @be_children = $parent->get_children();
                for my $child (@be_children)
                {
                    $child->set_parent($node);
                }
                $parent->set_parent($node);
                $parent->set_deprel('AuxV');
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
# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
