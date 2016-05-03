package Treex::Block::HamleDT::PL::Harmonize;
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
    default       => 'pl::ipipan',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

my $debug = 0;



#------------------------------------------------------------------------------
# Reads the Polish tree, converts morphosyntactic tags to Interset,
# converts dependency relations, transforms tree to adhere to PDT guidelines.
# ### TODO ###
# - improve convert_deprels(),
#   - handling of complements of all types (incl. subordination)
#   - NumArgs
#   - PrepArgs (seem to be working quite well)
# - improve coordination restructuring
#   (in particular for the sentence-level coordination with no 'pred' deprel)
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Phrase-based implementation of tree transformations (5.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::AlpinoToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    # Compose a tag string in the form expected by the pl::ipipan Interset driver.
    $conll_feat =~ s/\|/:/g;
    return "$conll_pos:$conll_feat";
}



#------------------------------------------------------------------------------
# Fixes tags and features for words for which the Polish tagset is too coarse
# grained.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $iset = $node->iset();
        # The source tagset does not distinguish between common and proper nouns.
        if($node->is_noun() && $lemma ne lc($lemma))
        {
            $iset->add('nountype' => 'prop');
        }
        elsif($form =~ m/^by$/i && $node->is_particle())
        {
            $iset->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'aspect' => 'imp', 'verbform' => 'fin', 'mood' => 'cnd'});
            $node->set_lemma('być');
        }
        # The correct form is 'się' but due to typos in the corpus we have to
        # look for 'sie' and 'sia' as well.
        elsif($form =~ m/^si[ęea]$/i && $node->is_particle())
        {
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex');
            $iset->set('typo' => 'typo') if($form =~ m/^si[ea]$/i);
        }
        # Demonstrative pronouns and determiners.
        elsif($lemma eq 'to' && $node->is_noun())
        {
            # Do not touch gender, number and case. Forms: tego, temu, to, tym.
            $iset->add('pos' => 'noun', 'prontype' => 'dem');
        }
        elsif($lemma =~ m/^(ten|taki|tamten|ów)$/ && $node->is_adjective())
        {
            # Forms: ten, ta, to, ci, tą, te, tę, tego, tej, temu, tych, tym, tymi.
            # Forms: taki, taka, takie, tacy, takiego, takiej, taką, takich, takim, takimi.
            $iset->add('pos' => 'adj', 'prontype' => 'dem');
        }
        elsif($lemma =~ m/^(kto|co)$/ && $node->is_noun())
        {
            # Forms: kto, kogo, komu, kim.
            # Forms: co, czego, czemu, czym.
            $iset->add('pos' => 'noun', 'prontype' => 'int|rel');
        }
        elsif($lemma =~ m/^(jaki|który|czyj)$/ && $node->is_adjective())
        {
            # Forms: jaki, jaka, jakie, jacy, jakiego, jakiej, jaką, jakich, jakim, jakimi.
            # Forms: który, która, które, którzy, którego, któremu, której, którą, których, którym, którymi.
            $iset->add('pos' => 'adj', 'prontype' => 'int|rel');
        }
        elsif($lemma =~ m/^(ktoś|coś|ktokolwiek|cokolwiek)$/ && $node->is_noun())
        {
            # Forms: ktoś, kogoś, komuś, kimś.
            # Forms: coś, czegoś, czemuś, czymś.
            # Forms: cokolwiek.
            $iset->add('pos' => 'adj', 'prontype' => 'ind');
        }
        elsif($lemma =~ m/^(jakiś|któryś|niejaki|niektóry|jakikolwiek|którykolwiek)$/ && $node->is_adjective())
        {
            $iset->add('pos' => 'adj', 'prontype' => 'ind');
        }
        elsif($lemma =~ m/^kilka/ && $node->is_numeral())
        {
            # kilka = how many; kilkaset = how many hundreds etc.
            # Forms: kilka, kilku, kilkoma.
            $iset->add('pos' => 'num', 'numtype' => 'card', 'prontype' => 'ind');
        }
        elsif($lemma =~ m/^(wszystko|wszyscy)$/ && $node->is_noun())
        {
            # Forms: wszystko, wszystkiego, wszystkim.
            $iset->add('pos' => 'noun', 'prontype' => 'tot');
        }
        elsif($lemma =~ m/^(każdy|wszystek|wszelki)$/ && $node->is_adjective())
        {
            # Forms: każdy, każda, każde, każdego, każdemu, każdym, każdej, każdą.
            $iset->add('pos' => 'adj', 'prontype' => 'tot');
        }
        elsif($lemma =~ m/^(nikt|nic)$/ && $node->is_noun())
        {
            # Forms: nikt, nikogo, nikomu, nikim.
            # Forms: nic, niczego, niczemu, niczym.
            $iset->add('pos' => 'noun', 'prontype' => 'neg');
        }
        elsif($lemma =~ m/^(żaden)$/ && $node->is_adjective())
        {
            # Forms: żaden, żadna, żadne, żadnego, żadnemu, żadnym, żadnej, żadną.
            $iset->add('pos' => 'adj', 'prontype' => 'neg');
        }
        # L-participles (past tense) should be participles, not finite verbs, because they sometimes combine with finite auxiliary verbs
        # and because they inflect for gender and not for person.
        # Note that after this step we will not be able to distinguish the l-participles from adjectival active past participles (-wszy),
        # unless we convert the latter to adjectives. In the long term we want to make them adjectives but it does not matter now because
        # they do not occur in the data.
        elsif($node->is_finite_verb() && $node->is_past())
        {
            $iset->add('verbform' => 'part', 'mood' => '', 'voice' => 'act');
        }
        # Verbal nouns should be nouns, not verbs.
        elsif($node->is_verb() && $node->is_gerund())
        {
            $iset->add('pos' => 'noun');
            # That was the easy part. But we also have to replace the verbal lemma (infinitive) by the nominal lemma (nominative singular).
            # The endings are -[nc]ie/ia/iu/iem/iom/iach/iami; except for genitive plural, where we have just -ń.
            my $newlemma = lc($form);
            if($node->is_genitive() && $node->is_plural())
            {
                $newlemma =~ s/ń$/nie/;
                log_warn("Unsure about lemma of verbal noun: genitive plural is '$form', suggested lemma is '$lemma'.");
            }
            else
            {
                $newlemma =~ s/i[eauo](m|ch|mi)?$/ie/;
            }
            # Negation.
            if($newlemma =~ m/^nie/ && $lemma !~ m/^nie/)
            {
                $newlemma =~ s/^nie//;
                $iset->add('negativeness' => 'neg');
            }
            $node->set_lemma($newlemma);
        }
        # Adjust the tag to the modified values of Interset.
        $self->set_pdt_tag($node);
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://zil.ipipan.waw.pl/FunkcjeZaleznosciowe
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# There are 25 distinct dependency relation tags: abbrev_punct adjunct aglt app
# aux comp comp_fin comp_inf complm cond conjunct coord coord_punct imp mwe ne
# neg obj obj_th pd pre_coord pred punct refl subj.
# In addition this method also handles tags that occur in the treebank by
# error: twice 'interp' instead of 'punct' and once 'ne_' instead of 'ne'.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    for my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->get_parent();
        # If the parent is a coordinating conjunction, the node modifies the entire coordination
        # and we have to examine the effective parents: the conjuncts.
        my $eparent = $parent;
        if ($parent->is_coordinator() || $parent->is_punctuation())
        {
            my @conjuncts = grep {$_->conll_deprel() eq 'conjunct'} $parent->children();
            if (@conjuncts)
            {
                ###!!! At the moment we ignore the possibility of a nested coordination, i.e. $conjunct[0] is again a conjunction.
                ###!!! We also ignore that the conjuncts may not all be the same part of speech.
                $eparent = $conjuncts[0];
            }
        }
        # pred ... predicate
        if ($deprel eq 'pred')
        {
            $node->set_deprel('Pred');
        }
        # subj ... subject
        elsif ($deprel eq 'subj')
        {
            $node->set_deprel('Sb');
        }
        # adjunct - 'a non-subcategorised dependent with the modifying function'
        elsif ($deprel eq 'adjunct')
        {
            # parent is a verb, an adjective or an adverb -> Adv
            # particle, e.g. "dopiero" = "only"
            ###!!! TODO: Restructure this!
            ###!!! "dopiero po przyjeździe" = "only after arrival" is analyzed as adjunct(dopiero, po); comp(po, przyjeździe)
            ###!!! but we want to get AuxP(po, przyjeździe); AuxZ(przyjeździe, dopiero).
            if ($eparent->iset()->pos() =~ m/^(verb|adj|adv|part)$/)
            {
                if ($node->is_subordinator() && $node->is_leaf())
                {
                    # If it is not leaf then its child will get SubArg and later
                    # transformations will cause this node to become AuxC.
                    $node->set_deprel('AuxC');
                }
                else
                {
                    $node->set_deprel('Adv');
                }
            }
            # parent is a noun -> Atr
            elsif ($eparent->is_noun() || $eparent->is_numeral())
            {
                $node->set_deprel('Atr');
            }
            ###!!! Node and parent are prepositions. Example: "diety od 1500 do 2000 złotych"; adjunct(diety, od); comp(od, 1500); adjunct(od, do); comp(do, 2000).
            ###!!! We may want to restructure structures like this one.
            elsif ($eparent->is_adposition())
            {
                $node->set_deprel('Atr');
            }
            # unknown part of speech of the parent, e.g. abbreviation (could be both noun and verb; all examples I have seen were nouns though)
            else
            {
                $node->set_deprel('Atr');
            }
        }
        # complement
        elsif ($deprel eq 'comp')
        {
            # parent is a preposition -> PrepArg - solved by a separate subroutine
            if ($eparent->is_adposition())
            {
                $node->set_deprel('PrepArg');
            }
            # parent is a subordinating conjunction -> SubArg - solved by a separate subroutine
            elsif ($eparent->is_subordinator())
            {
                $node->set_deprel('SubArg');
            }
            # parent is a numeral -> Atr (counted noun in genitive is governed by the numeral, like in Czech)
            elsif ($eparent->is_numeral())
            {
                $node->set_deprel('Atr');
            }
            # parent is a noun -> Atr
            elsif ($eparent->is_noun())
            {
                $node->set_deprel('Atr');
            }
            # parent is a verb
            # or adjective (especially deverbative: "zakończony")
            elsif ($eparent->is_verb() || $eparent->is_adjective())
            {
                # If the node is a coordinating conjunction, we must inspect the part of speech of its conjuncts.
                my $posnode = $node;
                if($node->is_coordinator() || $node->is_punctuation())
                {
                    my @conjuncts = grep {$_->conll_deprel() eq 'conjunct'} $node->children();
                    if(@conjuncts)
                    {
                        $posnode = $conjuncts[0];
                    }
                }
                # node is an adverb -> Adv
                if ($posnode->is_adverb())
                {
                    $node->set_deprel('Adv');
                }
                # node is an adjective -> Atv
                elsif ($posnode->is_adjective() || $posnode->is_participle())
                {
                    $node->set_deprel('Atv');
                }
                # node is a syntactic noun -> Obj
                ###!!! The reflexive pronoun "się" is (sometimes or always?) tagged "qub", i.e. particle. We may want to fix the part of speech as well.
                # Example: Jakiś czas mierzyli się wzrokiem. (For some time they measured each other.)
                elsif ($posnode->is_noun() or $posnode->conll_pos =~ m/(inf)|(ger)|(num)/ or $posnode->form() =~ m/^się$/i)
                {
                    $node->set_deprel('Obj');
                }
                # node is a preposition and for the moment it should hold the function of the whole prepositional phrase (which will later be propagated to the argument of the preposition)
                # this should work the same way as noun phrases -> Obj
                elsif ($posnode->is_adposition())
                {
                    $node->set_deprel('Obj');
                }
                # otherwise -> Atr
                else
                {
                    $node->set_deprel('Atr');
                }
            }
            # parent is an adverb
            # Example: odpowiednio do tego (in accord with that); comp(odpowiednio, do); comp(do, tego)
            elsif ($eparent->is_adverb())
            {
                $node->set_deprel('Adv');
            }
            # otherwise -> NR
            else
            {
                $node->set_deprel('Atr');
            }
        }
        # comp_inf ... infinitival complement
        # comp_fin ... clausal complement
        elsif ($deprel =~ m/^comp_(inf|fin)$/)
        {
            if ($eparent->is_adposition())
            {
                $node->set_deprel('PrepArg');
            }
            elsif ($eparent->is_subordinator())
            {
                $node->set_deprel('SubArg');
            }
            elsif ($eparent->is_noun())
            {
                $node->set_deprel('Atr');
            }
            elsif ($eparent->is_verb() || $eparent->is_adjective())
            {
                if ($node->is_adverb())
                {
                    $node->set_deprel('Adv');
                }
                elsif ($node->is_adjective())
                {
                    $node->set_deprel('Atv');
                }
                else
                {
                    $node->set_deprel('Obj')
                }
            }
            else
            {
                # Infinitive complements are usually labeled Obj in the Prague treebanks.
                $node->set_deprel('Obj');
            }
        }
        # obj ... object
        # obj_th ... dative object
        elsif ($deprel =~ m/^obj/)
        { # 'obj' and 'obj_th'
            $node->set_deprel('Obj');
        }
        # refl ... reflexive marker
        # TODO: how to decide between AuxT and Obj?
        elsif ($deprel eq 'refl')
        {
            $node->set_deprel('AuxT');
        }
        # neg ... negation marker
        elsif ($deprel eq 'neg')
        {
            $node->set_deprel('Neg');
        }
        # pd ... predicative complement
        elsif ($deprel eq 'pd')
        {
            $node->set_deprel('Pnom');
        }
        # ne ... named entity
        # ne_ ... one occurence – a typo?
        elsif ($deprel =~ m/^ne_?$/)
        {
            $node->set_deprel('Atr');
            # ### TODO ### interpunkce by mela dostat AuxG; struktura! - hlava by mela byt nejpravejsi uzel
        }
        # mwe ... multi-word expression
        # It occurs in compound prepositions (adverb + simple preposition) as the second element (preposition):
        # zgodnie z projektem ... XXX(PARENT, zgodnie); mwe(zgodnie, z); comp(zgodnie, projektem)
        # In PDT, such constructions are annotated using AuxP:
        # AuxP(PARENT, zgodnie); AuxP(zgodnie, z); XXX(zgodnie, projektem)
        elsif ($deprel eq 'mwe')
        {
            $node->set_deprel('AuxP');
        }
        # complm ... complementizer
        elsif ($deprel eq 'complm')
        {
            $node->set_deprel('AuxP');
        }
        # aglt ... mobile inflection
        elsif ($deprel eq 'aglt')
        {
            $node->set_deprel('AuxV');
        }
        # aux ... auxiliary
        elsif ($deprel eq 'aux')
        {
            $node->set_deprel('AuxV');
        }
        # app .. apposition
        # dependent on the first part of the apposition
        elsif ($deprel eq 'app')
        {
            $node->set_deprel('Apposition');
        }
        # coord ... coordinating conjunction
        # This label occurs only with top-level coordinations (coordinate predicates / clauses).
        # In other cases, the label of the coordination head reflects the coordination's relation to its parent.
        elsif ($deprel eq 'coord')
        {
            $node->wild()->{'coordinator'} = 1;
            $node->set_deprel('Pred');
        }
        # coord_punct ... punctuation instead of coordinating conjunction
        # As with coord, this label normally (except for one error) occurs only with top-level coordinations.
        # It is used for the punctuation symbol that serves as the coordination head; additional commas with three and more conjuncts are labeled just "punct".
        elsif ($deprel eq 'coord_punct')
        {
            $node->wild()->{'coordinator'} = 1;
            if ($parent->is_root())
            {
                # This deprel will be transfered to the conjuncts when coordination is processed.
                # We do not want the conjuncts to get 'AuxX'!
                $node->set_deprel('Pred');
            }
            elsif ($node->form eq ',')
            {
                $node->set_deprel('AuxX');
            }
            else
            {
                $node->set_deprel('AuxG');
            }
            # There is one error where this is not a top-level coordination, but it is a nested coordination, i.e. this node is a coordinator and a conjunct at the same time.
            ###!!! IT DOES NOT WORK AT THE MOMENT! Either we are calling it in a wrong context, or there is a problem with the detect_coordination() function.
            ###!!! Thus I am turning it off and temporarily leaving 5 untranslated deprels in the data.
            if (0 && !$parent->is_root() && any {$_->conll_deprel() eq 'conjunct'} ($parent->children()))
            {
                $node->set_deprel('CoordArg');
                $node->wild()->{'conjunct'} = 1;
            }
        }
        # conjunct
        elsif ($deprel eq 'conjunct')
        {
            # node is a coordination argument - solved in a separate subroutine
            $node->set_deprel('CoordArg');
            # node is a conjunct
            $node->wild()->{'conjunct'} = 1;
            # parent must be a coordinator (must it?)
            $parent->wild()->{'coordinator'} = 1;
        }
        # pre_coord ... pre-conjunction; first part of a correlative conjunction (such as English "either ... or")
        elsif ($deprel eq 'pre_coord')
        {
            $node->set_deprel('AuxY');
        }
        # punct ... punctuation marker
        elsif ($deprel eq 'punct')
        {
            # comma gets AuxX
            if ($node->form eq ',')
            {
                $node->set_deprel('AuxX');
            }
            # all other symbols get AuxG
            else
            {
                $node->set_deprel('AuxG');
            }
            # AuxK is assigned later in attach_final_punctuation_to_root()
        }
        # abbrev_punct ... abbreviation marker
        elsif ($deprel eq 'abbrev_punct')
        {
            $node->set_deprel('AuxG');
        }
        # cond ... conditional clitic
        elsif ($deprel eq 'cond')
        {
            $node->set_deprel('AuxV');
        }
        # imp ... imperative marker
        elsif ($deprel eq 'imp')
        {
            $node->set_deprel('AuxV');
        }
        else
        {
            $node->set_deprel('NR');
        }
    }
    # Make sure that all nodes now have their deprels.
    for my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if ( !$deprel )
        {
            $self->log_sentence($root);
            # If the following log is warn, we will be waiting for tons of warnings until we can look at the actual data.
            # If it is fatal however, the current tree will not be saved and we only will be able to examine the original tree.
            log_fatal( "Missing deprel for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my $sentence = $root->get_subtree_string();
    my @nodes = $root->get_descendants({'ordered' => 1});
    if($sentence =~ m/^Zachrobotało w bramie ?, zachrzęściło i błysnęła latarka Softa ?\. ?$/i)
    {
        my $zachrobotalo = $nodes[0];
        my $comma        = $nodes[3];
        my $zachrzescilo = $nodes[4];
        my $i            = $nodes[5];
        $zachrobotalo->set_parent($i);
        $zachrobotalo->set_deprel('CoordArg');
        $zachrobotalo->wild()->{'conjunct'} = 1;
        $zachrzescilo->set_parent($i);
        $zachrzescilo->set_deprel('CoordArg');
        $zachrzescilo->wild()->{'conjunct'} = 1;
        $comma->set_deprel('AuxX');
        delete($comma->wild()->{'coordinator'});
        $i->wild()->{'coordinator'} = 1;
    }
    elsif($sentence =~ m/^Włoszczyznę pokroić ?, kapustę poszatkować i razem udusić ?\. ?$/i)
    {
        my $pokroic     = $nodes[1];
        my $comma       = $nodes[2];
        my $poszatkowac = $nodes[4];
        my $i           = $nodes[5];
        $pokroic->set_parent($i);
        $pokroic->set_deprel('CoordArg');
        $pokroic->wild()->{'conjunct'} = 1;
        $poszatkowac->set_parent($i);
        $poszatkowac->set_deprel('CoordArg');
        $poszatkowac->wild()->{'conjunct'} = 1;
        $comma->set_deprel('AuxX');
        delete($comma->wild()->{'coordinator'});
        $i->wild()->{'coordinator'} = 1;
    }
    elsif($sentence =~ m/, 300 tys . zł pochodzić będzie z kredytu , a/i && scalar(@nodes)>13 && $nodes[13]->form() eq 'pochodzić')
    {
        my $comma     = $nodes[8];
        my $pochodzic = $nodes[13];
        my $a         = $nodes[18];
        $pochodzic->set_parent($a);
        $pochodzic->set_deprel('CoordArg');
        $pochodzic->wild()->{'conjunct'} = 1;
        delete($comma->wild()->{'coordinator'});
        $a->wild()->{'coordinator'} = 1;
    }
}



1;

=over

=item Treex::Block::HamleDT::PL::Harmonize

Converts trees coming from Polish Dependency Treebank via the CoNLL-X format to the style of
the HamleDT/Prague. Converts tags and restructures the tree.

=back

=cut

# Copyright 2013 Jan Mašek <honza.masek@gmail.com>

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
