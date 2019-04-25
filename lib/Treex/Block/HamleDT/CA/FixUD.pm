package Treex::Block::HamleDT::CA::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_xml_entities($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
    $self->fix_case_mark($root);
    $self->fix_acl_under_verb($root);
    $self->fix_coord_conj_head($root);
    $self->fix_advmod_obl($root);
    $self->fix_specific_constructions($root);
}



#------------------------------------------------------------------------------
# Decode XML entities left in the text.
#------------------------------------------------------------------------------
sub fix_xml_entities
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $n_changed_forms = 0;
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        # XML entity should only appear in XML files but elsewhere it should be decoded.
        if($form eq '&amp;')
        {
            $form = '&';
            $node->set_form($form);
            $n_changed_forms++;
        }
        my $lemma = $node->lemma();
        if($lemma eq '&amp;')
        {
            $lemma = '&';
            $node->set_lemma($lemma);
        }
    }
    # If we changed a form, we must re-generate the sentence text.
    if($n_changed_forms > 0)
    {
        $root->get_zone()->set_sentence($root->collect_sentence_text());
    }
}



#------------------------------------------------------------------------------
# Fixes known errors in lemmas, part-of-speech tags and morphological features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    my $ap = "'"; # Put the apostrofe to a variable to avoid syntax highlighting errors.
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $iset = $node->iset();
        # Now the positive approach: Tag certain closed-class words regardless the context.
        # For example, the forms of the personal pronoun "jo" occasionally appear as PROPN or X and we want to unify them.
        if($form =~ m/^(jo|em|m$ap|me|${ap}m|mi)$/i)
        {
            # "me" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 1st person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '1', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^jo$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^(em|m$ap|me|${ap}m)$/i)
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
            elsif($form =~ m/^mi$/i)
            {
                $iset->add('case' => 'acc', 'prepcase' => 'pre');
            }
        }
        elsif($form =~ m/^(tu|et|t$ap|te|${ap}t|ti)$/i)
        {
            $node->set_lemma('tu');
            # "te" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 2nd person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^tu$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^(et|t$ap|te|${ap}t)$/i)
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
            elsif($form =~ m/^ti$/i)
            {
                $iset->add('case' => 'acc', 'prepcase' => 'pre');
            }
        }
        elsif($form =~ m/^(nosaltres|nós|ens|nos|${ap}ns)$/i)
        {
            $node->set_lemma('jo');
            # "nos" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 1st person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '1', 'number' => 'plur');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^(nosaltres)$/i)
            {
                $iset->set('case' => 'nom');
            }
            else # nos
            {
                $iset->set('case' => 'dat|acc');
            }
        }
        elsif($form =~ m/^(vosaltres|vós|us|vos)$/i)
        {
            $node->set_lemma('tu');
            # "os" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 2nd person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'number' => 'plur');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^(vosaltres)$/i)
            {
                $iset->set('case' => 'nom');
            }
            else # os
            {
                $iset->set('case' => 'dat|acc');
            }
        }
        elsif($form =~ m/^(vostès?)$/i)
        {
            $node->set_lemma('tu');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'politeness' => 'pol');
            $iset->clear('degree', 'numtype', 'gender');
            if($form =~ m/^(vostè)$/i)
            {
                $iset->add('case' => 'nom|acc', 'number' => 'sing');
            }
            else # vostès
            {
                $iset->add('case' => 'nom|acc', 'number' => 'plur');
            }
        }
        elsif($form =~ m/^(ell|el|lo|${ap}l)$/i) # see below for "l'"
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'sing', 'gender' => 'masc');
            $iset->clear('degree', 'numtype');
            if($form =~ m/^ell$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^(el|l$ap|lo|${ap}l)$/i)
            {
                $iset->set('case' => 'acc');
            }
        }
        elsif($form =~ m/^(ella|la)$/i) # see below for "l'"
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'sing', 'gender' => 'masc');
            $iset->clear('degree', 'numtype');
            if($form =~ m/^ell$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^(el|l$ap|lo|${ap}l)$/i)
            {
                $iset->set('case' => 'acc');
            }
        }
        # "l'" can be either masculine or feminine
        elsif($form =~ m/^l$ap$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            $iset->set('case' => 'acc');
        }
        # "ho" is the neuter direct object
        elsif($form =~ m/^ho$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'sing', 'gender' => 'neut', 'case' => 'acc');
            $iset->clear('degree', 'numtype');
        }
        # The indirect object does not distinguish gender.
        elsif($form =~ m/^li$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            $iset->set('case' => 'dat');
        }
        elsif($form =~ m/^(ells)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'plur', 'gender' => 'masc', 'case' => 'nom');
            $iset->clear('degree', 'numtype');
        }
        elsif($form =~ m/^(elles)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'plur', 'gender' => 'fem', 'case' => 'nom');
            $iset->clear('degree', 'numtype');
        }
        # "els" can be masculine direct object, or indirect object in either gender
        elsif($form =~ m/^(els|los|${ap}ls)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'plur', 'case' => 'acc|dat');
            $iset->clear('gender', 'degree', 'numtype');
        }
        # "les" is the feminine direct object
        elsif($form =~ m/^(les)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'number' => 'plur', 'gender' => 'fem', 'case' => 'acc');
            $iset->clear('degree', 'numtype');
        }
        elsif($form =~ m/^(es|s$ap)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'reflex' => 'yes', 'case' => 'dat|acc', 'prepcase' => 'npr');
            $iset->clear('gender', 'number', 'degree', 'numtype');
        }
        elsif($form =~ m/^(si)$/i)
        {
            $node->set_lemma('ell');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'reflex' => 'yes', 'case' => 'acc', 'prepcase' => 'pre');
            $iset->clear('gender', 'number', 'degree', 'numtype');
        }
        # "hom" is an impersonal pronoun
        elsif($form =~ m/^hom$/i)
        {
            $node->set_lemma('hom');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3', 'case' => 'nom');
            $iset->clear('gender', 'number', 'degree', 'numtype');
        }
        # There are also "adverbial personal pronouns":
        # ablative/genitive "en", and locative "hi"
        elsif($form =~ m/^(en|n$ap|hi)$/i)
        {
            $iset->add('pos' => 'adv', 'prontype' => 'prs');
            $iset->clear('person', 'gender', 'number', 'case', 'degree', 'numtype');
        }
        # Even after the comprehensive categorization above there are determiners
        # tagged PROPN, e.g. possessive determiners "mi", "nuestro", and foreign
        # determiners such as "the". This is not allowed. The Spanish determiners
        # must be tagged DET. The foreign determiners must be either tagged DET,
        # or their deprel must be changed from det to flat.
        if($node->deprel() eq 'det' && $iset->is_proper_noun())
        {
            $iset->clear('nountype');
            $iset->add('pos' => 'adj', 'prontype' => 'prn');
        }
        # The "%" symbol should be tagged SYM. Now it is sometimes tagged NOUN.
        if($form eq '%')
        {
            $iset->set('pos', 'sym');
            $iset->clear('gender', 'number', 'case', 'degree', 'prontype', 'numtype', 'poss', 'reflex', 'verbform', 'mood', 'tense', 'person');
        }
        #----------------------------------------------------------------------
        # Check compatibility of features with part of speech.
        # The common gender should not be used in Spanish.
        # It should be empty, which means any gender, which in case of Spanish is masculine or feminine.
        if($iset->is_common_gender())
        {
            $iset->set('gender', '');
        }
        # The gender, number, person and verbform features cannot occur with adpositions, conjunctions, particles, interjections and punctuation.
        if($iset->pos() =~ m/^(adv|adp|conj|part|int|punc)$/)
        {
            $iset->clear('gender', 'number', 'person', 'verbform');
        }
        # The person feature also cannot occur with non-pronominal nouns, adjectives and numerals.
        if((($iset->is_noun() || $iset->is_adjective()) && !($iset->is_pronoun() || $iset->is_determiner())) || $iset->is_numeral())
        {
            $iset->clear('person');
        }
        # The verbform feature also cannot occur with pronouns, determiners and numerals.
        if($iset->is_pronoun() || $iset->is_numeral())
        {
            $iset->clear('verbform');
        }
        # The case feature can only occur with personal pronouns.
        if(!$iset->is_pronoun() || $form =~ m/^(uno|Éstas|l\')$/i) #'
        {
            $iset->clear('case');
        }
        # The mood and tense features can only occur with verbs.
        if(!$iset->is_verb())
        {
            $iset->clear('mood', 'tense');
        }
        # All numerals are tagged as cardinal. Distinguish ordinals.
        if($iset->is_numeral()) ###!!! THIS BLOCK MUST BE CATALANIZED!
        {
            if($form =~ m/^((decimo|(vi|tri|octo)gésimo)?(primer([oa]s?)?|segund[oa]s?|ter?cer([oa]s?)?|cuart[oa]s?|quint[oa]s?|sext[oa]s?|séptim[oa]s?|octav[oa]s?|noven[oa]s?)|(un|duo)?décim[oa]s?|(vi|tri|octo)gésim[oa]s?)$/i ||
               $form =~ m/^(1r[oa]s?|3er|4t[oa]s?|6[oa]s?|8v[oa]s?|\d+[oa]s?)$/)
            {
                # Ordinal numerals are tagged as adjectives because they behave so.
                $iset->set('pos', 'adj');
                $iset->set('numtype', 'ord');
            }
        } # is numeral
        # Irregular comparison of adjectives.
        if($iset->is_adjective())
        {
            if($form =~ m/^(millor|pitjor|major|menor)(e?s)?$/i)
            {
                $iset->set('degree', 'cmp');
            }
        } # is adjective
        # Adverbs of comparison.
        if($iset->is_adverb() && $form =~ m/^(més|menys)$/i)
        {
            $iset->set('degree', 'cmp');
        }
        # Fix verbs including auxiliaries.
        if($iset->is_verb())
        {
            # Every verb has a verbform. Those that do not have any verbform yet, are probably finite.
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
            # Catalan conditional is traditionally considered a tense rather than a mood.
            # Thus the morphological analysis did not know where to put it and lost the feature.
            # If the verb is tagged as indicative and does not have any tense, tag it as conditional.
            if($iset->is_indicative() && $iset->tense() eq '')
            {
                $iset->set('mood', 'cnd');
            }
            # Auxiliary verb must be tagged AUX, not VERB.
            # Copula must be tagged AUX, not VERB.
            # In lemmatized treebanks we want to do this only for approved auxiliary verbs.
            # However, we want it to work in unlemmatized treebanks too, so we add '_' as an approved lemma.
            if($lemma =~ m/^(ser|estar|haber|tener|ir|poder|saber|querer|deber|_)$/ && $node->deprel() =~ m/^aux(:|$)/ ||
               $lemma =~ m/^(ser|estar|_)$/ && $node->deprel() =~ m/^cop(:|$)/)
            {
                $node->set_tag('AUX');
                $node->iset()->set('verbtype', 'aux');
            }
        }
        # Mark words in foreign scripts.
        my $letters_only = $form;
        $letters_only =~ s/\PL//g;
        # Exclude also Latin letters.
        $letters_only =~ s/\p{Latin}//g;
        if($letters_only ne '')
        {
            $iset->set('foreign', 'fscript');
        }
    } # foreach node
}



#------------------------------------------------------------------------------
# After changes done to Interset (including part of speech) generates the
# universal part-of-speech tag anew.
#------------------------------------------------------------------------------
sub regenerate_upos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        $node->set_tag($node->iset()->get_upos());
    }
}



#------------------------------------------------------------------------------
# Fixes sentence-final punctuation attached to the artificial root node.
#------------------------------------------------------------------------------
sub fix_root_punct
{
    my $self = shift;
    my $root = shift;
    my @children = $root->children();
    if(scalar(@children)==2 && $children[1]->is_punctuation())
    {
        $children[1]->set_parent($children[0]);
        $children[1]->set_deprel('punct');
    }
}



#------------------------------------------------------------------------------
# Changes the relation between a preposition and a verb (infinitive) from case
# to mark. Miguel has done something in that direction but there are still many
# occurrences where this has not been fixed.
#------------------------------------------------------------------------------
sub fix_case_mark
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'case')
        {
            my $parent = $node->parent();
            # Most prepositions modify infinitives: para preparar, en ir, de retornar...
            # Some exceptions: desde hace cinco años
            if($parent->is_infinitive() || $parent->form() =~ m/^hace$/i) ###!!! THE HACE PATTERN, IF PRESENT IN CATALAN AT ALL, WILL HAVE DIFFERENT LEMMA
            {
                $node->set_deprel('mark');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Fixes deprels and sometimes even transforms specific constructions that we
# know are sometimes annotated wrongly.
#------------------------------------------------------------------------------
sub fix_specific_constructions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Determiners should not be attached as 'case'.
        if($node->is_determiner() && $node->deprel() =~ m/^case(:|$)/)
        {
            $node->set_deprel('det');
        }
        # Numerals should not be attached as 'case'.
        elsif($node->is_cardinal() && $node->deprel() =~ m/^case(:|$)/)
        {
            $node->set_deprel('nummod');
        }
        # Relative prepositional adverbial phrase "ante lo cual" ("before which")
        # has the preposition "ante" as the head, which is wrong.
        elsif($node->is_adposition() && $node->deprel() =~ m/^advmod(:|$)/)
        {
            my @children = $node->get_children({'ordered' => 1});
            # If there is 'fixed' or 'goeswith' among the children, the 'advmod'
            # relation may be correct (the whole expression may function as an
            # adverb).
            my @okchildren = grep {$_->deprel() =~ m/^(fixed|goeswith)(:|$)/} (@children);
            unless(@okchildren)
            {
                # We expect one normal child, plus possibly some punctuation children.
                my @nonpunctchildren = grep {$_->deprel() !~ m/^punct(:|$)/} (@children);
                if(scalar(@nonpunctchildren)==1)
                {
                    my $newhead = $nonpunctchildren[0];
                    $newhead->set_parent($node->parent());
                    $newhead->set_deprel('obl');
                    # Reattach the punctuation children, if any, to the new head.
                    foreach my $child (@children)
                    {
                        unless($child == $newhead)
                        {
                            $child->set_parent($newhead);
                        }
                    }
                    $node->set_parent($newhead);
                    $node->set_deprel('case');
                }
            }
        }
        # "Medio" is tagged 'NUM' but sometimes attached as 'det'; it should be 'nummod'.
        # Warning: $node->is_numeral() will return 1 even if the main tag is not NUM!
        # E.g. some indefinite articles are DET but they still have NumType=Card.
        elsif($node->tag() eq 'NUM' && $node->deprel() =~ m/^det(:|$)/)
        {
            $node->set_deprel('nummod');
        }
        # Occasionally a subordinating conjunction such as "porque" or "que" is
        # attached as 'advmod' instead of 'mark'.
        # Note that we want to do this only after we checked any specific errors
        # such as the "como si" above ("como" is also 'SCONJ').
        elsif($node->is_subordinator() && $node->deprel() =~ m/^advmod(:|$)/)
        {
            $node->set_deprel('mark');
        }
        # Apposition should be left-to-right and should not compete with flat.
        $self->fix_right_to_left_apposition($node);
        # AnCora reaches much broader for auxiliary verbs. Many of them should be main verbs in UD.
        $self->fix_auxiliary_verb($node);
    }
}



#------------------------------------------------------------------------------
# The co-occurrence of a title with a personal name is sometimes treated as
# apposition. It is wrong at least because apposition should not go right-to-
# left and here it goes from the name to the preceding title. However, it
# should probably be re-labeled as flat.
# Example: doña Esperanza Aguirre
#------------------------------------------------------------------------------
sub fix_right_to_left_apposition
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'appos' && $node->parent()->ord() > $node->ord())
    {
        my $right_member = $node->parent();
        $node->set_parent($right_member->parent());
        $node->set_deprel($right_member->deprel());
        $right_member->set_parent($node);
        $right_member->set_deprel('flat'); ###!!! or appos? How do we know?
    }
}



#------------------------------------------------------------------------------
# Changes the relation from an adverbial modifier to an oblique nominal
# dependent in cases where the dependent is not an adverb.
#------------------------------------------------------------------------------
sub fix_advmod_obl
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^advmod(:|$)/)
        {
            # Numeral could be a date. Example: el 16 de junio
            if($node->is_numeral())
            {
                # It is not guaranteed that it is a temporal modifier, so only use 'obl', not 'obl:tmod'.
                # Non-temporal examples include cincuenta in: más de cincuenta
                $node->set_deprel('obl');
            }
        }
    }
}



#------------------------------------------------------------------------------
# A clause attached to a verb cannot be acl, those are reserved to modifiers of
# nominals. It can be advcl, or xcomp (secondary predication) or it should be
# reattached to a nominal argument of the verb. A full disambiguation would
# have to be manual. We now resort to a simple relabeling to advcl.
#------------------------------------------------------------------------------
sub fix_acl_under_verb
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^acl(:|$)/ && $node->parent()->is_verb())
        {
            $node->set_deprel('advcl');
        }
    }
}



#------------------------------------------------------------------------------
# Some cooridnation in AnCora stays headed by a conjunction, fix it.
#------------------------------------------------------------------------------
sub fix_coord_conj_head
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Example: no sólo de sus calamidades, sino también de su historia
        # (not only of their calamities but also of their history)
        # Conjunctions "no sólo" and "sino también" are fixed expressions.
        # The phrase is currently headed by "sino" (cc), with children "no" (cc), calamidades (obl), and historia (obl).
        if($node->deprel() eq 'cc')
        {
            my @children = $node->get_children({'ordered' => 1});
            my @conjuncts = grep {$_->deprel() !~ m/^(fixed|goeswith|cc|punct)(:|$)/} (@children);
            my @delimiters = grep {$_->deprel() =~ m/^(cc|punct)(:|$)/} (@children);
            if(scalar(@conjuncts) >= 1)
            {
                my $newhead = $conjuncts[0];
                # Assume that the current deprel of the conjunct is correct.
                $newhead->set_parent($node->parent());
                # Attach the other conjuncts to the first conjunct.
                for(my $i = 1; $i <= $#conjuncts; $i++)
                {
                    $conjuncts[$i]->set_parent($newhead);
                    $conjuncts[$i]->set_deprel('conj');
                }
                # Add the original head to the set of delimiters.
                push(@delimiters, $node);
                @delimiters = sort {$a->ord() <=> $b->ord()} (@delimiters);
                # Attach each delimiter to the immediately following conjunct.
                # Attach it to the last conjunct if there is no following conjunct.
                foreach my $delimiter (@delimiters)
                {
                    while($delimiter->ord() > $conjuncts[0]->ord() && scalar(@conjuncts) > 1)
                    {
                        shift(@conjuncts);
                    }
                    $delimiter->set_parent($conjuncts[0]);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Fix auxiliary verb that should not be auxiliary.
#------------------------------------------------------------------------------
sub fix_auxiliary_verb
{
    my $self = shift;
    my $node = shift;
    if($node->tag() eq 'AUX')
    {
        # Fer often occurs in temporal expressions (analogy to Spanish "hacer"
        # as in "hace unos días" ("some days ago")): "des de fa setmanes"
        # ("since weeks ago").
        if($node->form() =~ m/^(fa|feia)$/i && $node->parent()->tag() =~ m/^(NOUN|PRON|DET|NUM|ADV)$/)
        {
            $node->set_tag('VERB');
            $node->iset()->clear('verbtype');
            my $nphead = $node->parent();
            $node->set_parent($nphead->parent());
            if($nphead->deprel() =~ m/^(obl|advmod|obj|nmod|appos)(:|$)/)
            {
                $node->set_deprel('advcl');
            }
            elsif($nphead->deprel() =~ m/^(root|conj)(:|$)/)
            {
                $node->set_deprel($nphead->deprel());
            }
            else
            {
                log_warn("Unexpected deprel '".$nphead->deprel()."' of a 'des de fa setmanes'-type phrase");
            }
            $nphead->set_parent($node);
            $nphead->set_deprel('obj');
            # If there were children of the NP head to the left of "hace" (e.g., punctuation),
            # they are now nonprojective. Reattach them to "hace".
            my @leftchildren = grep {$_->ord() < $node->ord()} ($nphead->children());
            foreach my $child (@leftchildren)
            {
                $child->set_parent($node);
            }
        }
        # Any verb that takes an infinitive, gerund or participle of another verb as complement
        # can be treated as auxiliary in the original treebank. We call them pseudo-auxiliaries
        # and promote them back to the head position.
        # We further assume (although it is not guaranteed) that all other
        # aux dependents of that infinitive are real auxiliaries.
        # If there were other spurious auxiliaries, it would matter
        # in which order we reattach them.
        # Examples:
        #   "suelen hablar" ("they are used to talk")
        #   "volverla a calentar" ("return her to warming") (causative auxiliary)
        #   "hacerle cometer faltas" ("make him commit faults")
        #   "no se deje asustar" ("does not let himself to get scared")
        # Similarly-looking pattern: "quedarse paralizados" ("stay paralyzed")
        # Here we have a participle instead of infinitive, and the auxiliary has
        # an "object" only because of the reflexive "se".
        # Examples with the gerund:
        #   "siguen teniendo" ("they keep having")
        #   "continuó presionando" ("he continued pressing")
        # The gerund can also be our right neighbor if it is a copula.
        # Examples:
        #   "sigue siendo uno de los hombres" ("stays being one of those men")
        # Instead of trying to enumerate all wrong lemmas, maybe we could just
        # list the lemmas that we approve of.
        # wrong (not exhaustive): $node->lemma() =~ m/^(añadir|considerar|decir|evitar|impedir|indicar|reclamar|ver)$/
        # wrong (not exhaustive): $node->lemma() =~ m/^(acabar|colar|comenzar|continuar|dejar|empezar|hacer|lograr|llegar|pasar|preguntar|quedar|seguir|soler|sufrir|tender|terminar|tratar|volver)$/
        # correct auxiliaries:    $node->lemma() =~ m/^(ser|estar|haber|ir|tener|deber|poder|saber|querer)$/
        # We must also approve the empty lemma '_', otherwise this method would mess up unlemmatized treebanks.
        my $approved_auxiliary = $node->lemma() =~ m/^(ser|estar|haver|anar|deber|poder|saber|querer|_)$/;
        my $approved_copula    = $node->lemma() =~ m/^(ser|estar|_)$/;
        # Warn if the lemma does not end in "-r" or "-re". That could mean that we have
        # a genuine auxiliary which is just wrongly lemmatized (e.g., "habiendo").
        # Of course it could also mean that we have a correct lemma of a non-verb.
        if($node->lemma() !~ m/re?$/ && $node->lemma() ne '_')
        {
            log_warn("AUX lemma '".$node->lemma()."' of '".$node->form()."' does not look like an infinitive.");
        }
        if(!$approved_auxiliary &&
           $node->deprel() =~ m/^aux(:|$)/ &&
           $node->parent()->ord() > $node->ord() &&
           ($node->parent()->is_infinitive() || $node->parent()->is_gerund() || $node->parent()->is_participle() ||
            defined($node->get_right_neighbor()) && $node->get_right_neighbor()->deprel() =~ m/^cop(:|$)/ &&
            ($node->get_right_neighbor()->is_infinitive() || $node->get_right_neighbor()->is_gerund() || $node->get_right_neighbor()->is_participle())) &&
           # We must be careful if this clause is a conjunct. We must not cause a conj relation to go right-to-left.
           ($node->parent()->deprel() !~ m/^conj(:|$)/ || $node->parent()->parent()->ord() < $node->ord())
          )
        {
            my $infinitive = $node->parent();
            # Sometimes there is a preposition between the pseudo-auxiliary and the infinitive, sometimes not.
            my $preposition; # a|al|de|del, maybe others?
            my @prepositions = grep {$_->is_adposition() && $_->ord() > $node->ord() && $_->ord() < $infinitive->ord()} ($infinitive->get_children({'ordered' => 1}));
            $preposition = $prepositions[0] if(scalar(@prepositions) >= 1);
            my $parent = $infinitive->parent();
            my $deprel = $infinitive->deprel();
            # If the content verb ($infinitive) is a participle instead of an infinitive,
            # it may have been attached as a non-clause; however, now we have definitely
            # a clause.
            $deprel =~ s/^nsubj/csubj/;
            $deprel =~ s/^i?obj/ccomp/;
            $deprel =~ s/^(advmod|obl)/advcl/;
            $deprel =~ s/^(nmod|amod|appos)/acl/;
            $node->set_parent($parent);
            $node->set_deprel($deprel);
            $infinitive->set_parent($node);
            $infinitive->set_deprel('xcomp');
            # Subject, adjuncts and other auxiliaries go up.
            # The preposition between the auxiliary and the infinitive, if present, stays with the infinitive.
            # Non-subject arguments go up if they occur before the auxiliary or between it and the infinitive.
            # (Example is the causative auxiliary: volver la a cometer faltas (la belongs to volver, faltas to cometer).)
            # Non-subject arguments occurring after the infinitive remain with the infinitive.
            my @children = $infinitive->children();
            foreach my $child (@children)
            {
                my $child_is_object = $child->deprel() =~ m/^(i?obj)(:|$)/ || $child->deprel() eq 'obl:arg';
                if($child_is_object && $child->ord() < $infinitive->ord() ||
                   ($child->deprel() =~ m/^(([nc]subj|advmod|discourse|vocative|aux|mark|cc|punct)(:|$)|obl$)/ ||
                    $child->deprel() =~ m/^obl:([a-z]+)$/ && $1 ne 'arg') &&
                   (!defined($preposition) || $child != $preposition))
                {
                    $child->set_parent($node);
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->set_tag('VERB');
            $node->iset()->clear('verbtype');
        }
        # Pseudo-auxiliaries that occur with finite clauses.
        # Examples:
        #   "para evitar que el Congresillo designe..." ("to prevent the Congress from designating...")
        #   "de ver que ayuda" ("to see that it helps")
        #   "tras indicar que ... sitúa" ("after indicating that ... situates")
        #   "evitar que se repitan los errores" ("prevent that the errors are repeated")
        #   "diciendo que le gustaría..." ("saying that they would like...")
        elsif(!$approved_auxiliary && $node->deprel() =~ m/^aux(:|$)/ &&
           defined($node->get_right_neighbor()) && $node->get_right_neighbor()->form() =~ m/^(que|si|cómo|:)$/i &&
           $node->parent()->ord() > $node->ord() &&
           # We must be careful if this clause is a conjunct. We must not cause a conj relation to go right-to-left.
           ($node->parent()->deprel() !~ m/^conj(:|$)/ || $node->parent()->parent()->ord() < $node->ord()))
           # We also do not need to check that the pseudo-auxiliary is an infinitive with a preposition.
           # Because there are cases where the pseudo-auxiliary is infinitive or gerund without preposition, and they are processed the same way.
           # $node->is_infinitive() && defined($node->get_left_neighbor()) && $node->get_left_neighbor()->form() =~ m/^(al|de|para|tras)$/i
        {
            my $complement = $node->parent();
            $node->set_parent($complement->parent());
            $node->set_deprel($complement->deprel());
            # Left siblings of the infinitive should depend on the infinitive. Probably it is just the preposition.
            my @left = grep {$_->ord() < $node->ord()} ($complement->children());
            foreach my $l (@left)
            {
                $l->set_parent($node);
            }
            $complement->set_parent($node);
            $complement->set_deprel('ccomp');
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->set_tag('VERB');
            $node->iset()->clear('verbtype');
        }
        # Copulas other than "ser" and "estar" should not be copulas.
        elsif((!$approved_copula && $node->deprel() =~ m/^cop(:|$)/ ||
               !$approved_auxiliary && $node->deprel() =~ m/^aux(:|$)/ && $node->parent()->is_adjective()) &&
              # We must be careful if this clause is a conjunct. We must not cause a conj relation to go right-to-left.
              ($node->parent()->deprel() !~ m/^conj(:|$)/ || $node->parent()->parent()->ord() < $node->ord()))
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
            # Subject, adjuncts and other auxiliaries go up.
            # We also have to raise conjunctions and punctuation, otherwise we risk nonprojectivities.
            # Noun modifiers remain with the nominal predicate.
            my @children = $pnom->children();
            foreach my $child (@children)
            {
                if($child->deprel() =~ m/^(([nc]subj|obj|advmod|discourse|vocative|aux|mark|cc|punct)(:|$)|obl$)/ ||
                   $child->deprel() =~ m/^obl:([a-z]+)$/ && $1 ne 'arg')
                {
                    $child->set_parent($node);
                }
            }
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->set_tag('VERB');
            $node->iset()->clear('verbtype');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CA::FixUD

This is a temporary block that should fix selected known problems in the Catalan UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
