package Treex::Block::HamleDT::ES::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_pos($root);
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_root_punct($root);
    $self->fix_case_mark($root);
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
        # XML entity should only appear in XML files but elsewhere it should be decoded.
        if($form eq '&amp;')
        {
            $form = '&';
            $node->set_form($form);
        }
        my $iset = $node->iset();
        # Pronouns and determiners that are neither pronouns nor determiners.
        if($iset->is_pronoun())
        {
            # Some words are tagged PRON instead of PROPN.
            if($form =~ m/^(Apenas|Art|Coordenadas|Creo|Crepúsculo|Don|Escándalo|Greybull|Kentrocapros|Mazomanie|Mé|Nación|OCDE|Pinauto|Siemens|Vaya|Volkswagen)$/)
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('nountype', 'prop');
            }
            elsif($form =~ m/^(actos|bolchevique|botella|célula|do|empresaria|hábitat|mella|modos|monumentos|nula|organismos|paella|reina|resto|sello|vuvuzelas)$/i)
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'noun');
            }
            elsif($form =~ m/^(6ta|buenas|determinadas|extremo|fuertes|medio|natural|numerosas|perfectas|poquita|semejante|susodichas|últim[oa]s?|único)$/i)
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'adj');
            }
            elsif($form =~ m/^(1|dos|tres|seis)$/i)
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'num');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(aparece|desapercibida|está|puedes|ser)$/i)
            {
                $iset->clear('prontype', 'case');
                $iset->set('pos', 'verb');
            }
            elsif($form =~ m/^(allí|cuando|donde)$/i)
            {
                $iset->clear('case', 'person');
                $iset->set('pos', 'adv');
            }
            elsif($form =~ m/^(al?|del)$/)
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'adp');
            }
            elsif($form eq 'si')
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'conj');
                $iset->set('conjtype', 'sub');
            }
            elsif($form eq '†')
            {
                $iset->clear('prontype', 'case', 'person');
                $iset->set('pos', 'sym');
            }
        }
        # Proper nouns that are not proper nouns.
        elsif($iset->is_proper_noun())
        {
            if($form =~ m/^yo$/i)
            {
                $iset->clear('nountype');
                $iset->set('prontype', 'prs');
                $iset->set('person', '1');
                $iset->set('number', 'sing');
                $iset->set('case', 'nom');
            }
            elsif($form =~ m/^tú$/i)
            {
                $iset->clear('nountype');
                $iset->set('prontype', 'prs');
                $iset->set('person', '2');
                $iset->set('number', 'sing');
                $iset->set('case', 'nom');
            }
        }
        # Numerals that are not numerals.
        elsif($iset->is_cardinal())
        {
            if($form =~ m/^(A64\/L14|Etelric|KF2|N|Nek2|Plk[14]|Tomás)$/)
            {
                $iset->clear('numtype');
                $iset->set('pos', 'noun');
                $iset->set('nountype', 'prop');
            }
            elsif($form =~ m/^(años?|condado|docena|esguince|km|límite|suma|terracota)$/i)
            {
                $iset->clear('numtype');
                $iset->set('pos', 'noun');
                $iset->set('nountype', 'com');
            }
            elsif($form =~ m/^(arquitectonica|corta|eterna|infinito|triple)$/i)
            {
                $iset->clear('numtype');
                $iset->set('pos', 'adj');
            }
            elsif($form =~ m/^(secondez)$/i)
            {
                $iset->clear('pos', 'numtype');
                $iset->set('foreign', 'foreign');
            }
            elsif($form =~ m/^(غدامس)$/i)
            {
                $iset->clear('pos', 'numtype');
                $iset->set('foreign', 'fscript');
            }
        }
        # Prepositions that are not prepositions.
        elsif($iset->is_adposition())
        {
            if($form =~ m/^(crítica|respecto|través)$/i)
            {
                $iset->set('pos', 'noun');
            }
            elsif($form =~ m/^(antiguo|mayores|sajón)$/i)
            {
                $iset->set('pos', 'adj');
            }
            elsif($form =~ m/^con([mts])igo$/i)
            {
                my $person = lc($1);
                $person = $person eq 'm' ? '1' : $person eq 't' ? '2' : '3';
                $iset->set('pos', 'noun');
                $iset->set('prontype', 'prs');
                $iset->clear('gender', 'definiteness', 'degree');
                $iset->set('number', 'sing');
                $iset->set('person', $person);
                $iset->set('case', 'com'); ###!!! Or we would have to split the token to two syntactic words, "con"+"mí".
            }
            elsif($form =~ m/^(cual)$/i)
            {
                $iset->set('pos', 'noun');
                $iset->set('prontype', 'int|rel');
            }
            elsif($form =~ m/^(tanto)$/i)
            {
                $iset->set('pos', 'adj');
                $iset->set('prontype', 'dem');
                $iset->set('numtype', 'card');
            }
            elsif($form =~ m/^(estuve)$/i)
            {
                $iset->set('pos', 'verb');
            }
            elsif($form =~ m/^(encima|más|menos|no|quizá)$/i)
            {
                $iset->set('pos', 'adv');
            }
            elsif($form =~ m/^(que)$/i)
            {
                $iset->set('pos', 'conj');
                $iset->set('conjtype', 'sub');
            }
            elsif($form =~ m/^(bilobular|vendice)$/i)
            {
                $iset->clear('pos');
            }
        }
        # Coordinating conjunctions that are not coordinating conjunctions.
        elsif($iset->is_coordinator())
        {
            if($form =~ m/^(bueno)$/i)
            {
                $iset->clear('conjtype');
                $iset->set('pos', 'adj');
            }
            elsif($form =~ m/^(aguarda|decir|sinó|volver)$/i)
            {
                $iset->clear('conjtype');
                $iset->set('pos', 'verb');
            }
            elsif($form =~ m/^(ya)$/i)
            {
                $iset->clear('conjtype');
                $iset->set('pos', 'adv');
            }
        }
        elsif($iset->is_subordinator())
        {
            if($form =~ m/^Krasicki$/)
            {
                $iset->clear('conjtype');
                $iset->set('pos', 'noun');
                $iset->set('nountype', 'prop');
            }
            elsif($form =~ m/^quién$/i)
            {
                $iset->clear('conjtype');
                $iset->set('pos', 'noun');
                $iset->set('prontype', 'int|rel');
            }
        }
        elsif($iset->is_punctuation())
        {
            if($form eq 'مات')
            {
                $iset->clear('pos');
                $iset->set('foreign', 'fscript');
            }
            elsif($form =~ m/\pL/ || $form eq '²')
            {
                $iset->clear('pos');
            }
        }
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
        # or their deprel must be changed from det to name.
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



1;

=over

=item Treex::Block::HamleDT::ES::FixUD

This is a temporary block that should fix selected known problems in the Spanish UD 1.1 treebank.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
