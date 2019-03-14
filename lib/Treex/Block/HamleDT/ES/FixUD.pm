package Treex::Block::HamleDT::ES::FixUD;
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
    $self->fix_pos($root);
#    $self->fix_morphology($root);
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
# Fixes known errors in part-of-speech tags. These errors were found when lists
# of words in closed categories were inspected.
#------------------------------------------------------------------------------
sub fix_pos
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $iset = $node->iset();
        # Now the positive approach: Tag certain closed-class words regardless the context.
        # For example, the forms of the personal pronoun "yo" occasionally appear as PROPN or X and we want to unify them.
        if($form =~ m/^(yo|me|mí|conmigo)$/i)
        {
            # "me" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 1st person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '1', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^yo$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^me$/i)
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
            elsif($form =~ m/^mí$/i)
            {
                $iset->add('case' => 'acc', 'prepcase' => 'pre');
            }
            else
            {
                # The comitative case semantically corresponds to "conmigo" but we normally do not speak about this case in Spanish.
                # Alternatively we could split "conmigo" to "con" + "mí" and use accusative.
                $iset->add('case' => 'com');
            }
        }
        elsif($form =~ m/^(tú|te|ti|contigo)$/i)
        {
            $node->set_lemma('tú');
            # "te" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 2nd person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'number' => 'sing');
            $iset->clear('gender', 'degree', 'numtype');
            if($form =~ m/^tú$/i)
            {
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^te$/i)
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
            elsif($form =~ m/^ti$/i)
            {
                $iset->add('case' => 'acc', 'prepcase' => 'pre');
            }
            else
            {
                # The comitative case semantically corresponds to "contigo" but we normally do not speak about this case in Spanish.
                # Alternatively we could split "contigo" to "con" + "ti" and use accusative.
                $iset->add('case' => 'com');
            }
        }
        # "sí" is ambiguous: either "yeas", or the prepositional case of reflexive "se".
        elsif($form =~ m/^(él|ello|le|lo|ella|la|ellos|les|los|ellas|las|el|se|consigo)$/i ||
              $form =~ m/^(sí)$/ && any {$_->is_adposition()} ($node->children()))
        {
            # Exclude DET because "la", "los" and "las" are ambiguous with definite articles.
            if($form =~ m/^el$/i ||
               $form =~ m/^(el|la|los|las)$/i && ($iset->is_adjective() || $node->deprel() eq 'det'))
            {
                $node->set_lemma('el');
                $iset->add('pos' => 'adj', 'prontype' => 'art', 'definiteness' => 'def');
                $iset->set('gender', $form =~ m/^(el|los)$/i ? 'masc' : 'fem');
                $iset->set('number', $form =~ m/^(el|la)$/i ? 'sing' : 'plur');
                $iset->clear('case', 'person', 'degree', 'numtype');
            }
            else
            {
                $node->set_lemma('él');
                $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '3');
                $iset->clear('degree', 'numtype');
                if($form =~ m/^(él|ello)$/i)
                {
                    $iset->add('case' => 'nom|acc', 'gender' => 'masc', 'number' => 'sing');
                }
                elsif($form =~ m/^le$/i)
                {
                    $iset->add('case' => 'dat', 'number' => 'sing');
                    $iset->clear('gender');
                }
                elsif($form =~ m/^lo$/i)
                {
                    $iset->add('case' => 'acc', 'prepcase' => 'npr', 'gender' => 'masc', 'number' => 'sing');
                }
                elsif($form =~ m/^(ella)$/i)
                {
                    $iset->add('case' => 'nom|acc', 'gender' => 'fem', 'number' => 'sing');
                }
                elsif($form =~ m/^(la)$/i)
                {
                    $iset->add('case' => 'acc', 'prepcase' => 'npr', 'gender' => 'fem', 'number' => 'sing');
                }
                elsif($form =~ m/^(ellos)$/i)
                {
                    $iset->add('case' => 'nom|acc', 'gender' => 'masc', 'number' => 'plur');
                }
                elsif($form =~ m/^les$/i)
                {
                    $iset->add('case' => 'dat', 'number' => 'plur');
                    $iset->clear('gender');
                }
                elsif($form =~ m/^los$/i)
                {
                    $iset->add('case' => 'acc', 'prepcase' => 'npr', 'gender' => 'masc', 'number' => 'plur');
                }
                elsif($form =~ m/^(ellas)$/i)
                {
                    $iset->add('case' => 'nom|acc', 'gender' => 'fem', 'number' => 'plur');
                }
                elsif($form =~ m/^(las)$/i)
                {
                    $iset->add('case' => 'acc', 'prepcase' => 'npr', 'gender' => 'fem', 'number' => 'plur');
                }
                elsif($form =~ m/^(se)$/i)
                {
                    $iset->add('case' => 'dat|acc', 'prepcase' => 'npr', 'reflex' => 'reflex');
                    $iset->clear('gender', 'number');
                }
                elsif($form =~ m/^(sí)$/i)
                {
                    $iset->add('case' => 'acc', 'prepcase' => 'pre', 'reflex' => 'reflex');
                    $iset->clear('gender', 'number');
                }
                else
                {
                    # The comitative case semantically corresponds to "consigo" but we normally do not speak about this case in Spanish.
                    # Alternatively we could split "consigo" to "con" + "sí" and use accusative.
                    $iset->add('case' => 'com', 'reflex' => 'reflex');
                    $iset->clear('gender', 'number');
                }
            }
        }
        elsif($form =~ m/^(nosotr[oa]s|nos)$/i)
        {
            $node->set_lemma('yo');
            # "nos" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 1st person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '1', 'number' => 'plur');
            $iset->clear('degree', 'numtype');
            if($form =~ m/^(nosotros)$/i)
            {
                $iset->add('case' => 'nom|acc', 'gender' => 'masc');
            }
            elsif($form =~ m/^(nosotras)$/i)
            {
                $iset->add('case' => 'nom|acc', 'gender' => 'fem');
            }
            else # nos
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
        }
        elsif($form =~ m/^(vosotr[oa]s|os)$/i)
        {
            $node->set_lemma('tú');
            # "os" can be also reflexive but we cannot decide it here. We will later look at the parent verb whether it is 2nd person.
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'number' => 'plur');
            $iset->clear('degree', 'numtype');
            if($form =~ m/^(vosotros)$/i)
            {
                $iset->add('case' => 'nom|acc', 'gender' => 'masc');
            }
            elsif($form =~ m/^(vosotras)$/i)
            {
                $iset->add('case' => 'nom|acc', 'gender' => 'fem');
            }
            else # os
            {
                $iset->add('case' => 'dat|acc', 'prepcase' => 'npr');
            }
        }
        elsif($form =~ m/^(usted(es)?)$/i)
        {
            $node->set_lemma('tú');
            $iset->add('pos' => 'noun', 'prontype' => 'prs', 'poss' => '', 'person' => '2', 'politeness' => 'pol');
            $iset->clear('degree', 'numtype', 'gender');
            if($form =~ m/^(usted)$/i)
            {
                $iset->add('case' => 'nom|acc', 'number' => 'sing');
            }
            else # ustedes
            {
                $iset->add('case' => 'nom|acc', 'number' => 'plur');
            }
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
    } # foreach node
}



#------------------------------------------------------------------------------
# Fixes known issues in features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $iset = $node->iset();
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
        if((($iset->is_noun() || $iset->is_adjective()) && !$iset->is_pronoun()) || $iset->is_numeral())
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
        # There are several issues with pronouns and determiners.
        if($iset->prontype() ne '' && $iset->is_adjective())
        {
            if($form =~ m/^(el|la|los|las)$/i)
            {
                $node->set_lemma('el');
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'def');
            }
            elsif($form =~ m/^un([oa]s?)?$/i)
            {
                $node->set_lemma('uno');
                $iset->set('prontype', 'art');
                $iset->set('definiteness', 'ind');
            }
        }
        # Do not touch the articles that we just recognized. Other determiners will be categorized together with pronouns.
        if($iset->prontype() ne '' && !$iset->is_article())
        {
            # Figure out the type of pronoun.
            if($form =~ m/^(yo|me|mí|nosotros|nos|tú|te|ti|vosotros|vos|os|usted|ustedes|él|ella|ello|le|lo|la|ellos|ellas|les|los|las|se)$/i)
            {
                $iset->set('prontype', 'prs');
                # For some reason, the second person plural pronouns have wrong lemmas (os:os, vos:vo, vosotros:vosotro).
                if($form =~ m/^(vosotros|vos|os)$/i)
                {
                    # The system used in the Spanish corpus: every person uses its own lemma. Just one lemma for both numbers and all forms in that person.
                    $node->set_lemma('tú');
                }
                # Some of the non-nominative personal pronouns got lemma "el" instead of "él".
                # The lemmatizer mistook them for definite articles.
                elsif($form =~ m/^(la|las|los)$/)
                {
                    $node->set_lemma('él');
                }
                # Mark reflexive pronouns.
                # In the first and the second persons, look whether the parent is a verb in the same person.
                if($form =~ m/^se$/i ||
                   $form =~ m/^(me|nos)$/i && defined($node->parent()) && $node->parent()->is_verb() && $node->parent()->iset()->is_first_person() ||
                   $form =~ m/^(te|v?os)$/i && defined($node->parent()) && $node->parent()->is_verb() && $node->parent()->iset()->is_second_person())
                {
                    $iset->set('reflex', 'reflex');
                }
            }
            elsif($form =~ m/^(mis?|nuestr[oa]s?|tus?|vuestr[oa]s?|sus?|suy[oa]s?)$/i)
            {
                $iset->set('prontype', 'prs');
                $iset->set('poss', 'poss');
            }
            elsif($form =~ m/^(aqu[eé]l(l[oa]s?)?|aquél|[eé]st?[aeo]s?|mism[oa]s?|tal(es)?)$/i)
            {
                $iset->set('prontype', 'dem');
            }
            elsif($form =~ m/^(tant[oa]s?)$/i)
            {
                $iset->set('prontype', 'dem');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(cada|tod[oa]s?)$/i)
            {
                $iset->set('prontype', 'tot');
            }
            elsif($form =~ m/^(amb[oa]s)$/i)
            {
                $iset->set('prontype', 'tot');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(nada|nadie|ning[uú]n[ao]?|niguna)$/i)
            {
                $iset->set('prontype', 'neg');
            }
            elsif($form =~ m/^(cu[aá]l(es)?|qu[eé]|qui[eé]n(es)?)$/i)
            {
                $iset->set('prontype', 'int|rel');
            }
            elsif($form =~ m/^(cuy[oa]s?)$/i)
            {
                $iset->set('prontype', 'int|rel');
                $iset->set('poss', 'poss');
            }
            elsif($form =~ m/^(cu[aá]n(t[oa]s?)?)$/i)
            {
                $iset->set('prontype', 'int|rel');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(bastantes?|demasiad[oa]s?|much[oa]s?|poc[oa]s?)$/i)
            {
                $iset->set('prontype', 'ind');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(menos|más)$/i)
            {
                $iset->set('prontype', 'ind');
                $iset->set('numtype', 'card');
                $iset->set('degree', 'cmp');
            }
            elsif($form =~ m/^(much[ií]simi?[oa]s?)$/i)
            {
                $iset->set('prontype', 'ind');
                $iset->set('numtype', 'card');
                $iset->set('degree', 'abs');
            }
            # algo alguien algun algún alguna algunas alguno algunos
            # cierta ciertas cierto ciertos cualquier cualquiera dicha dichas dicho dichos demás (demas)
            # diversas diversos otra otras otro otros sendas sendos un una unas uno unos varias varios
            else
            {
                $iset->set('prontype', 'ind');
            }
        } # is pronoun
        # All numerals are tagged as cardinal. Distinguish ordinals.
        if($iset->is_numeral())
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
            if($form =~ m/^(mejor|peor|mayor|menor)(es)?$/i)
            {
                $iset->set('degree', 'cmp');
            }
            elsif($form =~ m/^(óptim|pésim|máxim|mínim)[oa]s?$/i)
            {
                $iset->set('degree', 'sup');
            }
            elsif($form =~ m/ísim[oa]s?$/i)
            {
                $iset->set('degree', 'abs');
            }
        } # is adjective
        # Adverbs of comparison.
        if($iset->is_adverb() && $form =~ m/^(más|menos)$/i)
        {
            $iset->set('degree', 'cmp');
        }
        # Fix verbal features.
        if($iset->is_verb())
        {
            # Every verb has a verbform. Those that do not have any verbform yet, are probably finite.
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
            # Spanish conditional is traditionally considered a tense rather than a mood.
            # Thus the morphological analysis did not know where to put it and lost the feature.
            # If the verb is tagged as indicative and does not have any tense, tag it as conditional.
            if($iset->is_indicative() && $iset->tense() eq '')
            {
                $iset->set('mood', 'cnd');
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
    }
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
            if($parent->is_infinitive() || $parent->form() =~ m/^hace$/i)
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
        elsif($node->form() =~ m/^sí$/i && $node->deprel() =~ m/^advmod(:|$)/)
        {
            $node->set_tag('INTJ');
            $node->iset()->set('pos', 'int');
            $node->set_deprel('advcl');
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
        # Adverbial clause starting with "como si" is sometimes headed by "como" while
        # "si" is the 'mark' of the verb. Both "como" and "si" should be markers.
        elsif($node->form() =~ m/^como$/i)
        {
            my @children = $node->get_children({'ordered' => 1});
            my @verbs = grep {$_->is_verb()} (@children);
            if(scalar(@verbs) >= 1)
            {
                my $verb = $verbs[0];
                # We could now check for the presence of "si" under the verb but would its absence change anything?
                $verb->set_parent($node->parent());
                $verb->set_deprel('advcl');
                # Reattach all other children of "como" under the verb.
                foreach my $child (@children)
                {
                    unless($child == $verb)
                    {
                        $child->set_parent($verb);
                    }
                }
                # Reattach "como" to the verb.
                $node->set_parent($verb);
                $node->set_deprel('mark');
            }
        }
        # "Tanto" occurs in "tanto como", which functions as a compound conjunction.
        # However, as a pronoun (quantifier), it cannot be 'cc': "de tanta paciencia como veneno"
        elsif($node->lemma() eq 'tanto' && $node->is_pronoun() && $node->deprel() =~ m/^cc(:|$)/)
        {
            if($node->parent()->is_noun())
            {
                $node->set_deprel('det');
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
        # Hacer often occurs in temporal expressions like "hace unos días" ("some days ago").
        # hace 16 meses
        # hace algunos días
        # hace un par de días ("par" is the head)
        # hace poco (meaning "recently"; "poco" is adverb, the phrase is advmod instead of obl)
        # desde hacía tiempo
        if($node->form() =~ m/^(hace|hacía)$/i && $node->parent()->tag() =~ m/^(NOUN|PRON|DET|NUM|ADV)$/)
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
                log_warn("Unexpected deprel '".$nphead->deprel()."' of a 'hace unos días'-type phrase");
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
        elsif($node->lemma() =~ m/^(acabar|colar|comenzar|continuar|dejar|empezar|hacer|lograr|llegar|pasar|preguntar|quedar|seguir|soler|sufrir|tender|terminar|tratar|volver)$/ &&
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
        # Instead of trying to enumerate all wrong lemmas, maybe we could just
        # list the lemmas that we approve of.
        # wrong (not exhaustive): $node->lemma() =~ m/^(añadir|considerar|decir|evitar|impedir|indicar|reclamar|ver)$/
        # correct auxiliaries:    $node->lemma() =~ m/^(ser|estar|haber|ir|tener|deber|poder|saber|querer)$/
        my $approved_auxiliary = $node->lemma() =~ m/^(ser|estar|haber|ir|tener|deber|poder|saber|querer)$/;
        if(!$approved_auxiliary && $node->deprel() =~ m/^aux(:|$)/ &&
           defined($node->get_right_neighbor()) && $node->get_right_neighbor()->form() =~ m/^(que|:)$/i &&
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
        elsif($node->lemma() =~ m/^(dejar|encontrar|parecer)$/ &&
              ($node->deprel() eq 'cop' ||
               $node->deprel() =~ m/^aux(:|$)/ && $node->parent()->is_adjective()))
        {
            my $pnom = $node->parent();
            my $parent = $pnom->parent();
            my $deprel = $pnom->deprel();
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
        # "como diciendo" ("like saying")
        elsif($node->form() =~ m/^diciendo$/i && defined($node->get_left_neighbor()) && $node->get_left_neighbor()->form() =~ m/^como$/i)
        {
            my $como = $node->get_left_neighbor();
            $como->set_parent($node);
            $como->set_deprel('mark');
            $node->set_deprel('parataxis');
            # We also need to change the part-of-speech tag from AUX to VERB.
            $node->set_tag('VERB');
            $node->iset()->clear('verbtype');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::ES::FixUD

This is a temporary block that should fix selected known problems in the Spanish UD 1.1 treebank.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
