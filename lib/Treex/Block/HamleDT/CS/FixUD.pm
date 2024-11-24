package Treex::Block::HamleDT::CS::FixUD;
use utf8;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);
extends 'Treex::Block::HamleDT::Base'; # provides get_node_spanstring()



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
    # Oblique objects should be correctly identified during conversion from
    # Prague in Udep.pm. We repeat it here because of Czech-PUD, which is not
    # converted.
    $self->relabel_oblique_objects($root);
    foreach my $node (@nodes)
    {
        $self->fix_constructions($node);
        $self->fix_fixed_expressions($node);
        $self->fix_jak_znamo($root);
        $self->fix_annotation_errors($node);
        $self->identify_acl_relcl($node);
        $self->fix_copula_location($node);
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
    # PDT and related corpora annotate polarity on nouns, adjectives, verbs,
    # and adverbs. The one on nouns is most problematic and it is not annotated
    # too consistently. Deadjectival nouns (-ost) and deverbal nouns (-ní, -tí)
    # sometimes have it and sometimes don't. E.g., "nezávislost" is lemmatized
    # as "závislost" with Polarity=Neg. However, "neschopnost" is lemmatized
    # as "neschopnost" with Polarity=Pos. Same for many other negative nouns
    # like "neúspěch" or "nepřítel". In the Hičkok project we decided to never
    # annotate polarity on nouns and always lemmatize them with the ne- prefix
    # if they have it. For consistency, the same should now be done in the other
    # treebanks (possibly preserving the link to the positive form in LDeriv in
    # MISC).
    if($iset->is_noun())
    {
        if($lform =~ m/^ne/ && $iset->is_negative() && $lemma !~ m/^ne/)
        {
            $node->set_misc_attr('LDeriv', $lemma);
            $lemma = 'ne'.$lemma;
            $node->set_lemma($lemma);
        }
        $iset->clear('polarity');
    }
    # Some types of adjectives are gradable, others had comparative forms in
    # Old Czech only, and yet others do not have them at all. Make sure that
    # certain categories have non-empty degree feature even if they did not
    # have it in the original annotation.
    if($iset->is_adjective() && !$iset->is_pronominal() && $iset->numtype() eq '' && !$iset->is_possessive())
    {
        # Among those passing the above if-filter, we have the following sets:
        # - regular adjectives, long form (český, další, nový, jiný, velký...) => they have degree (although some of them, like "další" or "jiný", do not form comparative and superlative morphologically)
        # - short ("nominal") forms (rád, schopen, znám, možno, ochoten...) => they have degree (although comparatives are attested only in Old Czech)
        # - passive participles, long form (spojený, daný, příslušný, uvedený, zmíněný...) => they have degree (cmp and sup rare but possible: dodělaný, dodělanější, nejdodělanější)
        # - passive participles, short form (připraven, přesvědčen, uveden, řečen, určen...) => they have degree (for consistency/completeness; comparatives not attested)
        # - present active participles (rozhodující, vedoucí, následující, vynikající, týkající...) => they do not have degree
        # - past active participles (odstoupivší, zešílevší, byvší, doloživší, nastavší...) => they do not have degree
        if(!($iset->is_participle() && $iset->is_active()))
        {
            if($iset->degree() eq '')
            {
                $iset->set('degree', 'pos');
            }
        }
    }
    # A small set of less common numerals may be tagged ambiguously as
    # numtype=mult|sets. Members: jedny (sets); dvojí, obojí, obé, trojí (mult).
    if($iset->contains('numtype', 'mult') && $iset->contains('numtype', 'sets'))
    {
        if($lemma eq 'jedny')
        {
            $iset->set('pos', 'num');
            $iset->set('numtype', 'sets');
            if($node->deprel() =~ m/^amod(:|$)/)
            {
                $node->set_deprel('nummod');
            }
        }
        elsif($lemma =~ m/^(dvojí|obojí|obé|trojí)$/)
        {
            $iset->set('pos', 'adj');
            $iset->set('numtype', 'mult');
            if($node->deprel() =~ m/^nummod(:|$)/)
            {
                $node->set_deprel('amod');
            }
        }
    }
    # Jan Hajič's morphological analyzer tags "každý" simply as adjective,
    # but it is an attributive pronoun, according to the Czech grammar.
    if($lemma eq 'každý')
    {
        $node->iset()->set('pos', 'adj');
        $node->iset()->set('prontype', 'tot');
        $node->iset()->clear('degree');
        $node->iset()->clear('polarity');
        ###!!! This does not change the PDT tag (which may become XPOS in UD), which stays adjectival, e.g. AAMS1----1A----. Do we want to change it too?
        if($node->deprel() =~ m/^amod(:|$)/)
        {
            $node->set_deprel('det');
        }
        foreach my $edep ($node->get_enhanced_deps())
        {
            if($edep->[1] =~ m/^amod(:|$)/)
            {
                $edep->[1] = 'det';
            }
        }
    }
    # Pronoun (determiner) "sám" is difficult to classify in the traditional Czech system but in UD v2 we now have the prontype=emp, which is quite suitable.
    # Note that PDT assigns the long forms to a different lemma, "samý", but there is an overlap in meanings and we should probably merge the two lexemes.
    if($lemma =~ m/^(sám|samý)$/)
    {
        # Long forms: samý|samá|samé|samí|samého|samou|samému|samém|samým|samých|samými
        # Short forms: sám|sama|samo|sami|samy|samu
        # Mark the short forms with the variant feature and then unify the lemma.
        if($lform =~ m/^(sám|sama|samo|sami|samy|samu)$/i)
        {
            $node->iset()->set('variant', 'short');
        }
        $lemma = 'samý';
        $node->set_lemma($lemma);
        $node->iset()->set('pos', 'adj');
        $node->iset()->set('prontype', 'emp');
    }
    # Mark the verb 'být' as auxiliary regardless of context. In most contexts,
    # it is at least a copula (AUX in UD). Only in purely existential sentences
    # (without location) it will be the root of the sentence. But it is not
    # necessary to change the tag to VERB in these contexts. The tree structure
    # will contain the necessary information.
    if($lemma =~ m/^(být|bývat|bývávat)$/)
    {
        $iset->set('pos', 'verb');
        $iset->set('verbtype', 'aux');
        $iset->set('aspect', 'imp');
        ###!!! In two cases in Czech Poetry, "by" was wrongly tagged as SCONJ
        ###!!! and mark, although still lemmatized as "být".
        if($node->deprel() eq 'mark')
        {
            $node->set_deprel('aux');
        }
    }
    # The Czech conditional auxiliary "by" should not have the Person feature
    # (currently some occurrences have it and others don't, which is a mess).
    # Although it is used in the 3rd person most of the time, it can be also
    # 2nd person ("ty by ses bál" – decomposed to syntactic words as "ty by
    # jsi se bál"), and in Old Czech it can be other persons in other contexts.
    # Note that this rule should not affect the following (they should have
    # Person annotated):
    # - other conditional auxiliaries ("bych, bys, bychom, byste")
    # - "by" in Old Czech used as aorist of "být" (e.g. as a copula)
    # - "by" in code switching (Foreign=Yes, either conditional in other Slavic
    #   languages, or English preposition, or anything else)
    if($lform eq 'by' && $iset->is_verb() && $iset->is_conditional() && !$iset->is_foreign())
    {
        $lemma = 'být';
        $node->set_lemma($lemma);
        $iset->set('verbtype', 'aux');
        $iset->set('aspect', 'imp');
        $iset->set('verbform', 'fin');
        $iset->clear('tense');
        $iset->clear('person');
        $iset->clear('number');
        $iset->clear('gender');
    }
    # The word "proto" (lit. "for that") is etymologically a demonstrative
    # adverb but it is often used as a discourse connective: a coordinating
    # conjunction with a consecutive meaning. In either case it does not seem
    # appropriate to tag it as a subordinating conjunction – but it occurs in
    # the data.
    if($lform eq 'proto' && $iset->is_subordinator())
    {
        $iset->set_hash({'pos' => 'adv', 'prontype' => 'dem'});
        if($node->deprel() =~ m/^mark(:|$)/)
        {
            $node->set_deprel('advmod');
        }
    }
    # In PDT, the word "přičemž" ("and/where/while") is tagged as SCONJ but attached as Adv (advmod).
    # Etymologically, it is a preposition fused with a pronoun ("při+čemž"). We will re-tag it as adverb.
    # Similar cases: "zato" ("in exchange for what", literally "za+to" = "for+it").
    # This one is typically grammaticalized as a coordinating conjunction, similar to "but".
    # In some occurrences, we have "sice-zato", which is similar to paired cc "sice-ale".
    # But that is not a problem, other adverbs have grammaticalized to conjunctions too.
    # On the other hand, the following should stay SCONJ and the relation should change to mark:
    # "jakoby" ("as if"), "dokud" ("while")
    elsif($lform =~ m/^(přičemž|zato)$/)
    {
        $iset->set_hash({'pos' => 'adv', 'prontype' => 'rel'});
    }
    # If attached as 'advmod', "vlastně" ("actually") is an adverb and not a
    # converb of "vlastnit" ("to own").
    elsif($lform eq 'vlastně' && $deprel =~ m/^(cc|advmod)(:|$)/)
    {
        $lemma = 'vlastně';
        $node->set_lemma($lemma);
        # This is vlastně-2 ("totiž"), without the features of Degree and Polarity.
        # If the corpus contains any instances of the other adverb (derived from
        # the adjective "vlastní" ("own"), this step will erase its degree and
        # polarity, which is not desirable. However, the occurrence of the other
        # sense is not likely.
        $iset->set_hash({'pos' => 'adv'});
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
        if($deprel =~ m/^punct(:|$)/)
        {
            $deprel = 'cc';
            $node->set_deprel($deprel);
        }
    }
    # Identify passive deverbative adjectives and deverbative nouns.
    my $lderiv = $node->get_misc_attr('LDeriv');
    if(defined($lderiv))
    {
        # Identify passive deverbative adjectives (participles).
        # They could have the VerbForm feature in UD but the PDT
        # tags do not identify them as a distinct subclass.
        # (In contrast, the PDT tags do distinguish active participles
        # such as "dělající", "udělavší".)
        # Exclude derivations of the type "-elný", those are not passives.
        if($lderiv =~ m/(t|ci)$/ && $lemma =~ m/[^l][nt]ý$/ && $iset->is_adjective())
        {
            $iset->set('verbform', 'part');
            $iset->set('voice', 'pass');
        }
        # Identify deverbative nouns. They could have the VerbForm feature
        # in UD but the PDT tags do not identify them as a distinct subclass.
        elsif($lderiv =~ m/(t|ci)$/ && $lemma =~ m/[nt]í$/ && $iset->is_noun())
        {
            $iset->set('verbform', 'vnoun');
        }
    }
    # Present converbs have one common form (-c/-i) for singular feminines and neuters.
    # Try to disambiguate them based on the tree structure. There are very few
    # such converbs and only a fraction of them are neuters.
    if($node->is_verb() && $node->is_converb() && $node->form() =~ m/[ci]$/i)
    {
        my $neuter = 0;
        # The fixed expression 'tak říkajíc' has no actor; set it to neuter by default.
        if($node->form() =~ m/^říkajíc$/i && any {$_->form() =~ m/^tak$/i} ($node->children()))
        {
            $neuter = 1;
        }
        else
        {
            my $parent = $node->parent();
            if($parent->is_neuter() && !$parent->is_feminine())
            {
                $neuter = 1;
            }
            else
            {
                my @siblings = $parent->get_children();
                if(any {my $d = $_->deprel() // ''; defined($d) && $d =~ m/subj/ && $_->is_neuter() && !$_->is_feminine() && $_ != $node} (@siblings))
                {
                    $neuter = 1;
                }
            }
        }
        if($neuter)
        {
            $iset->set('number', 'sing');
            $iset->set('gender', 'neut');
        }
        else
        {
            $iset->set('number', 'sing');
            $iset->set('gender', 'fem');
        }
    }
    # Make sure that the UPOS tag still matches Interset features.
    $node->set_tag($node->iset()->get_upos());
    # Make sure that the XPOS tag still matches Interset features.
    ###!!! We probably have to improve the cs::pdt driver before we do this.
    ###!!! It fails on things such as pronominal adverbs (switching them to pronouns).
    ###!!! And it is questionable whether we want the XPOS tags of passive participles to be adjectives instead of verbs (although we do this in UPOS).
    #$node->set_conll_pos(encode('cs::pdt', $node->iset()));
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
    # Summer 2023 (after UD 2.12): Feature NumValue=1,2,3 finally recognized
    # as useless and removed from Czech UD data.
    $iset->clear('numvalue');
    # Same for Style=Arch. It would not be comparable across treebanks because
    # their texts are from different periods and what is archaic now may not
    # have been archaic 100 years ago.
    $iset->clear('style') if($iset->is_archaic());
}



#------------------------------------------------------------------------------
# Prepositional objects are considered oblique in many languages, although this
# is not a universal rule. They should be labeled "obl:arg" instead of "obj".
# This function (and the following one) is also defined in Udep.pm but we need
# a copy here so we can apply it to Czech-PUD, which is not converted from
# a Prague-style annotation.
#------------------------------------------------------------------------------
sub relabel_oblique_objects
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() =~ m/^i?obj(:|$)/)
        {
            if(!$self->is_core_argument($node))
            {
                $node->set_deprel('obl:arg');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Tells for a noun phrase in a given language whether it can be a core argument
# of a verb, based on its morphological case and adposition, if any. This
# method must be called after tree transformations because we look for the
# adposition among children of the current node, and we do not expect
# coordination to step in our way.
#------------------------------------------------------------------------------
sub is_core_argument
{
    my $self = shift;
    my $node = shift;
    my $language = $self->language();
    my @children = $node->get_children({'ordered' => 1});
    # Are there adpositions or other case markers among the children?
    my @adp = grep {$_->deprel() =~ m/^case(:|$)/} (@children);
    my $adp = scalar(@adp);
    # In Slavic and some other languages, the case of a quantified phrase may
    # be determined by the quantifier rather than by the quantified head noun.
    # We can recognize such quantifiers by the relation nummod:gov or det:numgov.
    my @qgov = grep {$_->deprel() =~ m/^(nummod:gov|det:numgov)$/} (@children);
    my $qgov = scalar(@qgov);
    # Case-governing quantifier even neutralizes the oblique effect of some adpositions
    # because there are adpositional quantified phrases such as this Czech one:
    # Výbuch zranil kolem padesáti lidí.
    # ("Kolem padesáti lidí" = "around fifty people" acts externally
    # as neuter singular accusative, but internally its head "lidí"
    # is masculine plural genitive and has a prepositional child.)
    ###!!! We currently ignore all adpositions if we see a quantified phrase
    ###!!! where the quantifier governs the case. However, not all adpositions
    ###!!! should be neutralized. In Czech, the prepositions "okolo", "kolem",
    ###!!! "na", "přes", and perhaps also "pod" can be neutralized,
    ###!!! although there may be contexts in which they should not.
    ###!!! Other prepositions may govern the quantified phrase and force it
    ###!!! into accusative, but the whole prepositional phrase is oblique:
    ###!!! "za třicet let", "o šest atletů".
    $adp = 0 if($qgov);
    # There is probably just one quantifier. We do not have any special rule
    # for the possibility that there are more than one.
    my $caseiset = $qgov ? $qgov[0]->iset() : $node->iset();
    # Tamil: dative, instrumental and prepositional objects are oblique.
    # Note: nominals with unknown case will be treated as possible core arguments.
    if($language eq 'ta')
    {
        return !$caseiset->is_dative() && !$caseiset->is_instrumental() && !$adp;
    }
    # Default: prepositional objects are oblique.
    # Balto-Slavic languages: genitive, dative, locative and instrumental cases are oblique.
    else
    {
        return !$adp
          && !$caseiset->is_genitive()
          && !$caseiset->is_dative()
          && !$caseiset->is_locative()
          && !$caseiset->is_ablative()
          && !$caseiset->is_instrumental();
    }
}



#------------------------------------------------------------------------------
# Figures out whether an adnominal clause is a relative clause, and changes the
# relation accordingly.
#------------------------------------------------------------------------------
sub identify_acl_relcl
{
    my $self = shift;
    my $node = shift;
    return unless($node->deprel() =~ m/^acl(:|$)/);
    # Look for a relative pronoun or a subordinating conjunction. The first
    # such word from the left is the one that matters. However, it is not
    # necessarily the first word in the subtree: there can be punctuation and
    # preposition. The relative pronoun can be even the root of the clause,
    # i.e., the current node, if the clause is copular.
    # Specifying (first|last|preceding|following)_only implies ordered.
    my @subordinators = grep {$_->is_subordinator() || $_->is_relative()} ($node->get_descendants({'preceding_only' => 1, 'add_self' => 1}));
    return unless(scalar(@subordinators) > 0);
    my $subordinator = $subordinators[0];
    # If there is a subordinating conjunction, the clause is not relative even
    # if there is later also a relative pronoun.
    return if($subordinator->is_subordinator() || $subordinator->deprel() =~ m/^mark(:|$)/);
    # Many words can be both relative and interrogative and the two functions are
    # not disambiguated in morphological features, i.e., they get PronType=Int,Rel
    # regardless of context. We only want to label a clause as relative if there
    # is coreference between the relative word and the nominal modified by the clause.
    # For example, 1. is a relative clause and 2. is not:
    # 1. otázka, která se stále vrací (question that recurs all the time)
    # 2. otázka, která strana vyhraje volby (question which party wins the elections)
    # Certain interrogative-relative words seem to never participate in a proper
    # relative clause.
    return if($subordinator->lemma() =~ m/^(jak|kolik)$/);
    # The interrogative-relative adverb "proč" ("why") could be said to corefer with a few
    # selected nouns but not with others. Note that the parent can be also a
    # pronoun (typically the demonstrative/correlative "to"), which is also OK.
    my $parent = $node->parent();
    return if($subordinator->lemma() eq 'proč' && $parent->lemma() !~ m/^(důvod|příčina|záminka|ten|to)$/);
    # An incomplete list of nouns that can occur with an adnominal clause which
    # resembles but is not a relative clause. Of course, all of them can also be
    # modified by a genuine relative clause.
    my $badnouns = 'argument|dotaz|důkaz|kombinace|kritérium|možnost|myšlenka|nařízení|nápis|názor|otázka|pochopení|pochyba|pomyšlení|pravda|problém|projekt|průzkum|představa|přehled|příklad|rada|údaj|úsloví|uvedení|východisko|zkoumání|způsob';
    # The interrogative-relative pronouns "kdo" ("who") and "co" ("what") usually
    # occur with one of the "bad nouns". We will keep only the remaining cases
    # where they occur with a different noun or pronoun. This is an approximation
    # that will not always give correct results.
    return if($subordinator->lemma() =~ m/^(kdo|co)$/ && $parent->lemma() =~ m/^($badnouns)$/);
    # The relative words are expected only with certain grammatical relations.
    # The acceptable relations vary depending on the depth of the relative word.
    # In depth 0, the relation is acl, which is not acceptable anywhere deeper.
    my $depth = 0;
    for(my $i = $subordinator; $i != $node; $i = $i->parent())
    {
        $depth++;
    }
    return if($depth > 0 && $subordinator->lemma() =~ m/^(kdo|co|což|který|kterýžto|jaký)$/ && $subordinator->deprel() !~ m/^(nsubj|obj|iobj|obl)(:|$)/);
    # The relative (never interrogative!) pronoun "jenž" can also appear as nmod
    # or det, if its possessive variants "jehož", "jejíž", "jejichž" are used.
    return if($depth > 0 && $subordinator->lemma() =~ m/^(jenž|jehož|jejíž|jejichž)$/ && $subordinator->deprel() !~ m/^(nsubj|obj|iobj|obl|nmod|det)(:|$)/);
    return if($subordinator->lemma() =~ m/^(kam|kde|kdy|kudy|odkud|proč)$/ && $subordinator->deprel() !~ m/^advmod(:|$)/);
    ###!!! We do not rule out the "bad nouns" for the most widely used relative
    ###!!! word "který" ("which"). However, this word can actually occur in
    ###!!! fake relative (interrogative) clauses. We may want to check the bad
    ###!!! nouns and agreement in gender and number; if the relative word agrees
    ###!!! with the bad noun, the clause is recognized as relative, otherwise
    ###!!! it is not.
    $node->set_deprel('acl:relcl');
}



#------------------------------------------------------------------------------
# Attempts to guess whether a node heads a temporal modifier, based on its
# lemma. Needed in fix_copula_location() below, where temporal modifiers should
# have lower priority than locations and other adverbials. Besides temporal
# modifiers, the function also flags other adverbs that are unlikely to be the
# predicate.
#------------------------------------------------------------------------------
sub is_unlikely_adverbial_predicate
{
    my $self = shift;
    my $node = shift;
    return
        # temporal
        $node->lemma() =~ m/^(kdy|někdy|vždy(cky)?|pokaždé|nikdy|teď|nyní|právě|tentokrát|tehdy|tenkrát|pozdě(ji)?|pak|poté|potom|už|již|dosud|dříve|dávno|brzy|teprve|zatím|ještě|stále|nadále|pořád|opět|nakonec|často|dlouho|zároveň|současně|doba|čas|období|momentálně|chvíle|chvilka|vteřina|vteřinka|sekunda|minuta|minutka|hodina|hodinka|ráno|dopoledne|poledne|odpoledne|večer|noc|půlnoc|den|denně|dnes|dodnes|včera|předevčírem|zítra|pozítří|pondělí|úterý|středa|čtvrtek|pátek|sobota|neděle|svátek|víkend|týden|velikonoce|vánoce|měsíc|měsíčně|leden|únor|březen|duben|květen|červen|červenec|srpen|září|říjen|listopad|prosinec|čtvrtletí|kvartál|jaro|léto|podzim|zima|prázdniny|ročně|letos|loni|napřesrok|dekáda|století|éra|novověk|středověk|starověk|pravěk|minulost|současno(st)?|budoucno(st)?)$/i
        || # other unlikely
        $node->lemma() =~ m/^(dokonce|hodně|jednou|ještě|jistě|konečně|málo|méně|mimochodem|moc|možná|najednou|naopak|naprosto|naštěstí|navíc|obdobně|opravdu|osobně|ostatně|plně|podobně|podstata|prakticky|pravděpodobně|proč|prostě|proto|především|přesto|přičemž|přitom|rovněž|samozřejmě|skutečně|stejně|také|údajně|určitě|většinou|více|vlastně|zcela|zřejmě)$/i;
}



#------------------------------------------------------------------------------
# Identifies existential-locative clauses of the type "to be somewhere" and
# transforms them to copular clauses. This is a Czech-specific step because in
# (Czech) PDT, such clauses are not treated as copular but in UD v2 they
# they should. For example, both "V ledničce je jídlo" and "Jídlo je
# v ledničce" should be treated as if "je" were a copula, i.e., the structure
# should be similar to "Jídlo je dobré".
#------------------------------------------------------------------------------
sub fix_copula_location
{
    my $self = shift;
    my $node = shift;
    # Is this node the copular verb "být"?
    return unless($node->lemma() eq 'být');
    # If it is already a copula or auxiliary, do not do anything.
    return if($node->deprel() =~ m/^(cop|aux)(:|$)/);
    my @children = $node->children();
    return unless(scalar(@children) > 0);
    # Does it have one or more adverbial modifiers?
    # (Ignore adverbial clauses because those would bring up the double subject problem, and they are unlikely anyway.)
    ###!!! Exclude "přece" in fixed expression "přece jenom", it would later get relabeled "cc" and could not serve as a head.
    # Also exclude other particles ("jen") that are unlikely to function as predicates.
    # Sort it so that temporal modifiers have lower priority, i.e. come later in the list.
    my @adverbials = sort
    {
        my $at = $self->is_unlikely_adverbial_predicate($a);
        my $bt = $self->is_unlikely_adverbial_predicate($b);
        my $r = ($at && !$bt) ? 1 : (!$at && $bt) ? -1 : 0;
        unless($r)
        {
            $r = $a->ord() <=> $b->ord()
        }
        $r
    }
    (grep {$_->deprel() =~ m/^(obl|advmod)(:|$)/ && $_->lemma() !~ m/^(asi|jen|přece|už)$/i} (@children));
    return unless(scalar(@adverbials) > 0);
    ###!!! If there are multiple adverbials, we should prefer location over time. But we cannot distinguish them.
    # Make the first adverbial the head.
    # Attach the other children and the copula to it.
    my $new_head = shift(@adverbials);
    my @other_children = grep {$_ != $new_head} (@children);
    # There are a few sentences where the transformation would result in
    # right-to-left coordination. We could attempt to transform the coordination
    # too, but the actual constructions are unusual and maybe it will be safer
    # to leave them as they are.
    return if($node->deprel() =~ m/^conj(:|$)/ && $node->parent()->ord() > $new_head->ord());
    return if(any {$_->deprel() =~ m/^conj(:|$)/ && $new_head->ord() > $_->ord()} @other_children);
    $new_head->set_parent($node->parent());
    $new_head->set_deprel($node->deprel());
    foreach my $child (@other_children)
    {
        $child->set_parent($new_head);
    }
    $node->set_parent($new_head);
    $node->set_deprel('cop');
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
    ###!!! We do not want to see thousands of warnings if the dataset does not
    ###!!! contain lemmas.
    if(!defined($node->lemma()))
    {
        $node->set_lemma('');
    }
    # In "Los Angeles", "Los" is wrongly attached to "Angeles" as 'cc'.
    if(lc($node->form()) eq 'los' && $parent->is_proper_noun() &&
       $parent->ord() > $node->ord())
    {
        my $grandparent = $parent->parent();
        $deprel = $parent->deprel();
        $node->set_parent($grandparent);
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('flat');
        $parent = $grandparent;
    }
    # In "Tchaj wan", "wan" is wrongly attached to "Tchaj" as 'cc'.
    elsif(lc($node->form()) eq 'wan' && $node->is_proper_noun() &&
          lc($parent->form()) eq 'tchaj' &&
          $parent->ord() < $node->ord())
    {
        $deprel = 'flat';
        $node->set_deprel($deprel);
    }
    # "skupiny Faith No More": for some reason, "Faith" is attached to "skupiny" as 'advmod'.
    elsif($node->is_noun() && $parent->is_noun() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'nmod';
        $node->set_deprel($deprel);
    }
    # "v play off"
    elsif($node->is_noun() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
    }
    # An initial ("K", "Z") is sometimes mistaken for a preposition, although
    # it is correctly tagged PROPN.
    elsif($node->is_proper_noun() && $parent->is_proper_noun() && $deprel =~ m/^case(:|$)/)
    {
        my $grandparent = $parent->parent();
        $deprel = $parent->deprel();
        $node->set_parent($grandparent);
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('flat');
        $parent = $grandparent;
    }
    # "většinou" ("mostly") is the noun "většina", almost grammaticalized to an adverb.
    elsif(lc($node->form()) eq 'většinou' && $node->is_noun() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
    }
    # "v podstatě" ("basically") is a prepositional phrase used as an adverb.
    # Similar: "ve skutečnosti" ("in reality")
    elsif($node->form() =~ m/^(podstatě|skutečnosti)$/i && $deprel =~ m/^(cc|advmod)(:|$)/)
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
    }
    # The noun "pravda" ("truth") used as sentence-initial particle is attached
    # as 'cc' but should be attached as 'discourse'.
    elsif(lc($node->form()) eq 'pravda' && $deprel =~ m/^(cc|advmod)(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
    }
    # There are a few right-to-left appositions that resulted from transforming
    # copula-like constructions with punctuation (":") instead of the copula.
    # Each of them would probably deserve a different analysis but at present
    # we do not care too much and make them 'parataxis' (they occur in nonverbal
    # sentences or segments).
    elsif($deprel =~ m/^appos(:|$)/ && $node->ord() < $parent->ord())
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
    # In "jakýs takýs", both words are DET and "jakýs" is attached to "takýs"
    # as 'cc', which is wrong.
    elsif($node->is_determiner() && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'det';
        $node->set_deprel($deprel);
    }
    # The abbreviation "aj" ("a jiné" = "and other") is tagged as an adjective
    # but sometimes it is attached to the last conjunct as 'cc'. We should re-
    # attach it as a conjunct. We may also consider splitting it as a multi-
    # word token.
    # Similar: "ad" ("a další" = "and other")
    # Note: "ad" is sometimes tagged ADJ and sometimes even NOUN.
    elsif($node->form() =~ m/^(ad|aj)$/i && ($node->is_adjective() || $node->is_noun()) && $deprel =~ m/^cc(:|$)/)
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
    # An adverb should not depend on a copula but on the nominal part of the
    # predicate. Example: "Také vakovlk je, respektive před vyhubením byl, ..."
    elsif($node->is_adverb() && $node->deprel() =~ m/^advmod(:|$)/ &&
          $parent->deprel() =~ m/^cop(:|$)/)
    {
        $parent = $parent->parent();
        $node->set_parent($parent);
    }
    # The expression "nejen že" ("not only") functions as a multi-word first part of a multi-word conjunction.
    # It is often written as one word ("nejenže"). When it is written as two words, "že" should not be a sibling "mark"; it should be "fixed".
    elsif(lc($node->form()) eq 'nejen' && defined($node->get_right_neighbor()) &&
          $node->get_right_neighbor()->ord() == $node->ord()+1 &&
          lc($node->get_right_neighbor()->form()) eq 'že')
    {
        my $ze = $node->get_right_neighbor();
        $ze->set_parent($node);
        $ze->set_deprel('fixed');
        foreach my $child ($ze->children())
        {
            $child->set_parent($node);
        }
    }
    # The expression "více než" ("more than") functions as an adverb.
    elsif(lc($node->form()) eq 'než' && $parent->ord() == $node->ord()-1 &&
          lc($parent->form()) eq 'více')
    {
        $deprel = 'fixed';
        $node->set_deprel($deprel);
        $parent->set_deprel('advmod') unless($parent->parent()->is_root());
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
    # The expression "suma sumárum" ("to summarize") functions as an adverb.
    elsif(lc($node->form()) eq 'suma' && $parent->ord() == $node->ord()+1 &&
          lc($parent->form()) eq 'sumárum')
    {
        my $grandparent = $parent->parent();
        $deprel = $parent->deprel();
        $node->set_parent($grandparent);
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('fixed');
        $parent = $grandparent;
    }
    # The expression "nota bene" functions as an adverb.
    elsif(lc($node->form()) eq 'nota' && $parent->ord() == $node->ord()+1 &&
          lc($parent->form()) eq 'bene')
    {
        my $grandparent = $parent->parent();
        $deprel = $parent->deprel();
        $node->set_parent($grandparent);
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('fixed');
        $parent = $grandparent;
    }
    # The expression "in memoriam" functions as an adverb.
    elsif(lc($node->form()) eq 'memoriam' && $parent->ord() == $node->ord()-1 &&
          lc($parent->form()) eq 'in')
    {
        $deprel = 'fixed';
        $node->set_deprel($deprel);
    }
    # The expression "ex ante" functions as an adverb.
    elsif(lc($node->form()) eq 'ante' && $parent->ord() == $node->ord()-1 &&
          lc($parent->form()) eq 'ex')
    {
        $deprel = 'fixed';
        $node->set_deprel($deprel);
    }
    # In PDT, "na úkor něčeho" ("at the expense of something") is analyzed as
    # a prepositional phrase with a compound preposition (fixed expression)
    # "na úkor". However, it is no longer fixed if a possessive pronoun is
    # inserted, as in "na její úkor".
    # Similar: "na základě něčeho" vs. "na jejichž základě"
    # Similar: "v čele něčeho" vs. "v jejich čele"
    elsif($node->form() =~ m/^(úkor|základě|čele)$/i && lc($parent->form()) =~ m/^(na|v)$/ &&
          $parent->ord() == $node->ord()-2 &&
          $parent->parent()->ord() == $node->ord()-1)
    {
        my $possessive = $parent->parent();
        my $na = $parent;
        $parent = $possessive->parent();
        $deprel = $possessive->deprel();
        $node->set_parent($parent);
        $node->set_deprel($deprel);
        $na->set_parent($node);
        $na->set_deprel('case');
        $possessive->set_parent($node);
        $possessive->set_deprel($possessive->is_determiner() ? 'det' : $possessive->is_adjective() ? 'amod' : 'nmod');
    }
    # In one case, "v jejich čele" has already the right structure but the deprel of "čele" is wrong ('det').
    elsif($node->form() =~ m/^čele$/i && $deprel =~ m/^det(:|$)/)
    {
        $deprel = 'nmod';
        $node->set_deprel($deprel);
    }
    # Similarly, "na rozdíl od něčeho" ("in contrast to something") is normally
    # a fixed expression (multi-word preposition "na rozdíl od") but occasionally
    # it is not fixed: "na rozdíl třeba od Mikoláše".
    # More inserted nodes: "na rozdíl např . od sousedního Německa"
    # Similar: "ve srovnání například s úvěry"
    elsif(!$parent->is_root() && !$parent->parent()->is_root() &&
          defined($parent->get_right_neighbor()) && defined($node->get_left_neighbor()) &&
          $node->form() =~ m/^(od|se?)$/i &&
          $parent->form() =~ m/^(na|ve)$/i && $parent->ord() <= $node->ord()-3 &&
          $node->get_left_neighbor()->form() =~ m/^(rozdíl|srovnání)$/i && $node->get_left_neighbor()->ord() <= $node->ord()-2 &&
          $parent->get_right_neighbor()->ord() <= $node->ord()-1)
    {
        # Dissolve the fixed expression and give it ordinary analysis.
        my $noun = $parent->parent();
        my $na = $parent;
        my $rozdil = $node->get_left_neighbor();
        my $od = $node;
        $parent = $noun->parent();
        $deprel = $noun->deprel();
        $rozdil->set_parent($parent);
        $rozdil->set_deprel($deprel);
        $na->set_parent($rozdil);
        $na->set_deprel('case');
        $noun->set_parent($rozdil);
        $noun->set_deprel('nmod');
        $parent = $noun;
        $deprel = 'case';
        $od->set_parent($parent);
        $od->set_deprel($deprel);
        # Any punctuation on the left hand should be re-attached to preserve projectivity.
        my @punctuation = grep {$_->deprel() =~ m/^punct(:|$)/ && $_->ord() < $rozdil->ord()} ($noun->children());
        foreach my $punct (@punctuation)
        {
            $punct->set_parent($rozdil);
        }
    }
    # "nehledě na" is normally a fixed multi-word preposition but not if
    # another word is inserted: "nehledě tedy na"
    elsif($node->form() =~ m/^na$/i && !$parent->is_root() &&
          $parent->form() =~ m/^nehledě$/i && $parent->ord() <= $node->ord()-2)
    {
        $parent = $parent->parent();
        $deprel = 'case';
        $node->set_parent($parent);
        $node->set_deprel($deprel);
    }
    # In PDT, the words "dokud" ("while") and "jakoby" ("as if") are sometimes
    # attached as adverbial modifiers although they are conjunctions.
    elsif($node->is_subordinator() && $deprel =~ m/^advmod(:|$)/ && scalar($node->children()) == 0)
    {
        $deprel = 'mark';
        $node->set_deprel($deprel);
    }
    # "a jak" ("and as") should not be treated as a fixed expression and not even as a constituent.
    elsif(lc($node->form()) eq 'a' && $parent->ord() == $node->ord()+1 &&
          lc($parent->form()) eq 'jak' && $parent->is_subordinator() && !$parent->deprel() =~ m/^root(:|$)/)
    {
        $parent->set_deprel('mark');
        $parent = $parent->parent();
        $deprel = 'cc';
        $node->set_parent($parent);
        $node->set_deprel($deprel);
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
    # Similar: "míněno" (ADJ, passive participle of "mínit")
    elsif($node->form() =~ m/^(rozuměj|dejme|míněno|nedala|nevím|počínaje|řekněme|říkajíc|srov(nej)?|víš|víte|event)$/i && $deprel =~ m/^(cc|advmod|mark)(:|$)/)
    {
        $deprel = 'parataxis';
        $node->set_deprel($deprel);
    }
    # "chtě nechtě" (converbs of "chtít", "to want") is a fixed expression with adverbial meaning.
    elsif($node->form() =~ m/^(chtě|chtíc)$/ && $parent->ord() == $node->ord()+1 &&
          $parent->form() =~ m/^(nechtě|nechtíc)$/)
    {
        my $grandparent = $parent->parent();
        $node->set_parent($grandparent);
        $deprel = 'advcl';
        $node->set_deprel($deprel);
        $parent->set_parent($node);
        $parent->set_deprel('fixed');
        $parent = $grandparent;
    }
    # "cestou necestou": both are NOUN, "cestou" is attached to "necestou" as 'cc'.
    elsif($node->is_noun() && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'nmod';
        $node->set_deprel($deprel);
    }
    # "tip ťop": both are ADJ, "tip" is attached to "ťop" as 'cc'.
    elsif($node->is_adjective() && $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'amod';
        $node->set_deprel($deprel);
    }
    # "pokud ovšem" ("if however") is sometimes analyzed as a fixed expression
    # but that is wrong because other words may be inserted between the two
    # ("pokud ji ovšem zákon připustí").
    elsif(lc($node->form()) eq 'ovšem' && $deprel =~ m/^fixed(:|$)/ &&
          lc($parent->form()) eq 'pokud')
    {
        $parent = $parent->parent();
        $deprel = 'cc';
        $node->set_parent($parent);
        $node->set_deprel($deprel);
    }
    # "jako kdyby", "i kdyby", "co kdyby" ... "kdyby" is decomposed to "když by",
    # first node should form a fixed expression with the first conjunction
    # while the second node is an auxiliary and should be attached higher.
    elsif($node->lemma() eq 'být' && !$parent->is_root() &&
          $parent->deprel() =~ m/^mark(:|$)/ &&
          $parent->ord() == $node->ord()-2 &&
          defined($node->get_left_neighbor()) &&
          $node->get_left_neighbor()->ord() == $node->ord()-1 &&
          $node->get_left_neighbor()->form() =~ m/^(aby|když)$/)
    {
        my $kdyz = $node->get_left_neighbor();
        my $grandparent = $parent->parent();
        $node->set_parent($grandparent);
        $node->set_deprel('aux');
        $parent = $grandparent;
        $kdyz->set_deprel('fixed');
    }
    # "jak" can be ADV or SCONJ. If it is attached as advmod, we will assume that it is ADV.
    # same for 'jakkoli' and 'jakkoliv'
    elsif($node->lemma() =~ m/^jak(koliv?)?$/ && $node->is_conjunction() && $deprel =~ m/^advmod(:|$)/)
    {
        $node->iset()->set('pos' => 'adv');
        $node->iset()->clear('conjtype');
        $node->set_tag('ADV');
    }
    # "ať" is a particle in Czech grammar but it is sometimes tagged as SCONJ in the Prague treebanks.
    # It may function as a 3rd-person imperative marker: "ať laskavě táhne k čertu".
    # We could thus analyze it as an auxiliary, similar to Polish "niech", but
    # first we would have to put it on the list of approved Czech auxiliaries,
    # and then we should make sure that all other occurrences are analyzed similarly.
    elsif($node->form() =~ m/^ať$/i && $node->is_conjunction() && $deprel =~ m/^advmod(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
    }
    # "no" (Czech particle)
    elsif(lc($node->form()) eq 'no' && $node->is_particle() && !$node->is_foreign() &&
          $deprel =~ m/^cc(:|$)/)
    {
        $deprel = 'discourse';
        $node->set_deprel($deprel);
        # In sequences like "no a", "no" may be attached to "a" but there is no reason for it.
        if($parent->deprel() =~ m/^cc(:|$)/ && $parent->ord() == $node->ord()+1)
        {
            $parent = $parent->parent();
            $node->set_parent($parent);
        }
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
    # Punctuation can be exceptionally root, otherwise it is always attached as punct.
    elsif($node->is_punctuation() && $deprel !~ m/^(punct|root)(:|$)/)
    {
        $deprel = 'punct';
        $node->set_deprel($deprel);
    }
    $self->fix_auxiliary_verb($node);
    $self->fix_pokud_mozno($node);
    $self->fix_a_to($node);
    $self->fix_to_jest($node);
    # Functional nodes normally do not have modifiers of their own, with a few
    # exceptions, such as coordination. Most modifiers should be attached
    # directly to the content word.
    if($node->deprel() =~ m/^(aux|cop)(:|$)/)
    {
        my @children = grep {$_->deprel() =~ m/^(nsubj|csubj|obj|iobj|expl|ccomp|xcomp|obl|advmod|advcl|vocative|dislocated|dep)(:|$)/} ($node->children());
        my $parent = $node->parent();
        foreach my $child (@children)
        {
            $child->set_parent($parent);
        }
    }
    elsif($node->deprel() =~ m/^(case|mark|cc|punct)(:|$)/)
    {
        my @children = grep {$_->deprel() !~ m/^(conj|fixed|goeswith|punct)(:|$)/} ($node->children());
        my $parent = $node->parent();
        foreach my $child (@children)
        {
            $child->set_parent($parent);
        }
    }
    # In PDT, isolated letters are sometimes attached as punctuation:
    # - either 'a', 'b', 'c' etc. used as labels of list items,
    # - or 'o', probably used as a surrogate for a bullet of a list item.
    # In PDT-C, these tokens are tagged Q3-------------, converted to NOUN in UD,
    # but they are still attached as punctuation, leading to a violation of the
    # UD guidelines. Make them nmod instead.
    # There is also one occurrence where 'O' is tagged F%-------------, converted to X in UD, yet attached as punctuation.
    if($node->deprel() =~ m/^punct(:|$)/ && ($node->is_noun() || $node->is_foreign()))
    {
        $node->set_deprel('nmod');
    }
}



#------------------------------------------------------------------------------
# Fix fixed multiword expressions.
#------------------------------------------------------------------------------
my @_fixed_expressions;
my @fixed_expressions;
BEGIN
{
    # This function processes multiword expressions that should be annotated
    # as fixed (regardless what their annotation in PDT was), as well as those
    # that may be considered fixed by some, but should not. For those that should
    # not be fixed we provide the prescribed tree structure; if the expression
    # should not be one constituent, all components will be attached to the same
    # parent outside the expression; alternatively, those that already are attached
    # outside can keep their attachment (this can be signaled by parent=-1 instead
    # of 0; deprel should still be provided just in case the node has its parent
    # inside and we have to change it).
    @_fixed_expressions =
    (
        # lc(forms), mode, UPOS tags, ExtPos, deps (parent:deprel)
        # modes:
        # - always ... apply as soon as the lowercased forms match
        # - catena ... apply only if the nodes already form a catena in the tree (i.e. avoid accidental grabbing random collocations)
        # - subtree .. apply only if the nodes already form a full subtree (all descendants included in the expression)
        # - fixed .... apply only if it is already annotated as fixed (i.e. just normalize morphology and add ExtPos)
        #---------------------------------------------------------
        # Multiword adverbs.
        ['a priori',           'always',  'a priori',           'X X',                 'F%------------- F%-------------',                 'foreign=yes|extpos=adv foreign=yes',       '0:advmod 1:fixed'],
        ['co možná',           'always',  'co možná',           'ADV ADV',             'Db------------- Db-------------',                 'pos=adv|extpos=adv pos=adv',               '0:advmod 1:fixed'],
        ['de facto',           'always',  'de facto',           'X X',                 'F%------------- F%-------------',                 'foreign=yes|extpos=adv foreign=yes',       '0:advmod 1:fixed'],
        # "M. J." can be somebody's initials (connected as flat, nmod, or even as siblings), and it is difficult to distinguish.
        ['m . j .',            'subtree', 'mimo . jiný .',      'ADP PUNCT ADJ PUNCT', 'Q3------------- Z:------------- Q3------------- Z:-------------', 'pos=adp|abbr=yes|extpos=adv pos=punc pos=adj|abbr=yes|case=acc|degree=pos|gender=neut|number=sing|polarity=pos pos=punc', '0:advmod 1:punct 1:fixed 3:punct'],
        ['nejen že',           'always',  'nejen že',           'ADV SCONJ',           'Db------------- J,-------------',                 'pos=adv|extpos=adv pos=conj|conjtype=sub', '0:advmod 1:fixed'],
        ['přece jen',          'always',  'přece jen',          'PART PART',           'TT------------- TT-------------',                 'pos=part|extpos=adv pos=part', '0:advmod 1:fixed'],
        ['přece jenom',        'always',  'přece jenom',        'PART PART',           'TT------------- TT-------------',                 'pos=part|extpos=adv pos=part', '0:advmod 1:fixed'],
        # Expressions like "týden co týden": Since the "X co X" pattern is not productive,
        # we should treat it as a fixed expression with an adverbial meaning.
        # Somewhat different in meaning but identical in structure is "stůj co stůj", and it is also adverbial.
        ['stůj co stůj',       'always',  'stát co stát',       'VERB ADV VERB',       'Vi-S---2--A-I-- Db------------- Vi-S---2--A-I--', 'pos=verb|aspect=imp|mood=imp|number=sing|person=2|polarity=pos|verbform=fin|extpos=adv pos=adv pos=verb|aspect=imp|mood=imp|number=sing|person=2|polarity=pos|verbform=fin', '0:advmod 1:fixed 1:fixed'],
        ['čtvrtek co čtvrtek', 'always',  'čtvrtek co čtvrtek', 'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['den co den',         'always',  'den co den',         'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['měsíc co měsíc',     'always',  'měsíc co měsíc',     'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['neděli co neděli',   'always',  'neděle co neděle',   'NOUN ADV NOUN',       'NNFS4-----A---- Db------------- NNFS4-----A----', 'pos=noun|case=acc|gender=fem|number=sing|extpos=adv pos=adv pos=noun|case=acc|gender=fem|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['noc co noc',         'always',  'noc co noc',         'NOUN ADV NOUN',       'NNFS4-----A---- Db------------- NNFS4-----A----', 'pos=noun|case=acc|gender=fem|number=sing|extpos=adv pos=adv pos=noun|case=acc|gender=fem|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['pátek co pátek',     'always',  'pátek co pátek',     'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['rok co rok',         'always',  'rok co rok',         'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['sobotu co sobotu',   'always',  'sobota co sobota',   'NOUN ADV NOUN',       'NNFS4-----A---- Db------------- NNFS4-----A----', 'pos=noun|case=acc|gender=fem|number=sing|extpos=adv pos=adv pos=noun|case=acc|gender=fem|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['středu co středu',   'always',  'středa co středa',   'NOUN ADV NOUN',       'NNFS4-----A---- Db------------- NNFS4-----A----', 'pos=noun|case=acc|gender=fem|number=sing|extpos=adv pos=adv pos=noun|case=acc|gender=fem|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['týden co týden',     'always',  'týden co týden',     'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        ['večer co večer',     'always',  'večer co večer',     'NOUN ADV NOUN',       'NNIS4-----A---- Db------------- NNIS4-----A----', 'pos=noun|animacy=inan|case=acc|gender=masc|number=sing|extpos=adv pos=adv pos=noun|animacy=inan|case=acc|gender=masc|number=sing',                                                 '0:advmod 1:fixed 1:fixed'],
        # Multiword prepositions.
        # Psané bez francouzské diakritiky je to nejednoznačné, mohlo by to chytit i "letiště JFK a La Guardia". Potřebovali bychom se asi omezit na případy, kdy už to bylo značené jako fixed, a jen přidat ExtPos.
        #['a la',               'a la',               'X X',                 'F%------------- F%-------------',                 'foreign=yes|extpos=adp foreign=yes', '0:case 1:fixed'],
        ['à la',               'always',  'a la',               'X X',                 'F%------------- F%-------------',                 'foreign=yes|extpos=adp foreign=yes', '0:case 1:fixed'],
        ###!!!['v průběhu',          'v průběh',           'ADP NOUN',            'RR--6---------- NNIS6-----A----',                 'pos=adp|adpostype=prep|case=loc|extpos=adp pos=noun|nountype=com|gender=masc|animacy=inan|number=sing|case=loc', '0:case 1:fixed'],
        ###!!!['v rámci',            'v rámec',            'ADP NOUN',            'RR--6---------- NNIS6-----A----',                 'pos=adp|adpostype=prep|case=loc|extpos=adp pos=noun|nountype=com|gender=masc|animacy=inan|number=sing|case=loc', '0:case 1:fixed'],
        # Multiword subordinators.
        ['i když',             'always',  'i když',             'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor|extpos=sconj pos=conj|conjtype=sub', '0:mark 1:fixed'],
        # Multiword coordinators.
        # There is a dedicated function fix_a_to() (called from fix_constructions() before coming here), which make sure that the right instances of "a sice" and "a to" are annotated as fixed expressions.
        ['a sice',             'always',  'a sice',             'CCONJ PART',          'J^------------- TT-------------',                 'pos=conj|conjtype=coor|extpos=cconj pos=part', '0:cc 1:fixed'],
        ['a to',               'fixed',   'a to',               'CCONJ PART',          'J^------------- TT-------------',                 'pos=conj|conjtype=coor|extpos=cconj pos=part', '0:cc 1:fixed'],
        # There is a dedicated function fix_to_jest() (called from fix_constructions() before coming here), which make sure that the right instances of "to je" and "to jest" are annotated as fixed expressions.
        ['to je',              'fixed',   'ten být',            'DET AUX',             'PDNS1---------- VB-S---3P-AAI--',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|verbtype=aux|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp', '0:cc 1:fixed'],
        ['to jest',            'fixed',   'ten být',            'DET AUX',             'PDNS1---------- VB-S---3P-AAI-2',                 'pos=adj|prontype=dem|gender=neut|number=sing|case=nom|extpos=cconj pos=verb|verbtype=aux|polarity=pos|number=sing|person=3|verbform=fin|mood=ind|tense=pres|voice=act|aspect=imp', '0:cc 1:fixed'],
        # The following expressions should not be annotated as fixed.
        ['a jestli',           'always',  'a jestli',           'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=sub',  '-1:cc -1:mark'],
        ['a jestliže',         'always',  'a jestliže',         'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=sub',  '-1:cc -1:mark'],
        ['a pokud',            'always',  'a pokud',            'CCONJ SCONJ',         'J^------------- J,-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=sub',  '-1:cc -1:mark'],
        ['a tak',              'always',  'a tak',              'CCONJ CCONJ',         'J^------------- J^-------------',                 'pos=conj|conjtype=coor pos=conj|conjtype=coor', '0:cc 0:cc'],
        ['alespoň pokud',      'always',  'alespoň pokud',      'ADV SCONJ',           'Db------------- J,-------------',                 'pos=adv pos=conj|conjtype=sub',                 '0:advmod:emph 0:mark'],
        ['asi jako',           'always',  'asi jako',           'PART SCONJ',          'TT------------- J,-------------',                 'pos=part pos=conj|conjtype=sub',                '-1:advmod -1:mark'],
        ['ať již',             'always',  'ať již',             'SCONJ ADV',           'J,------------- Db-------------',                 'pos=conj|conjtype=sub pos=adv',                 '0:mark 0:advmod'],
        ['ať už',              'always',  'ať už',              'SCONJ ADV',           'J,------------- Db-------------',                 'pos=conj|conjtype=sub pos=adv',                 '0:mark 0:advmod'],
        ['pokud možno',        'always',  'pokud možný',        'SCONJ ADJ',           'J,------------- ACNS------A----',                 'pos=conj|conjtype=sub pos=adj|polarity=pos|gender=neut|number=sing|degree=pos|variant=short', '2:mark 0:advcl'],
    );
    foreach my $e (@_fixed_expressions)
    {
        my $expression = $e->[0];
        my @forms = split(/\s+/, $e->[0]);
        my $mode = $e->[1];
        my @lemmas = defined($e->[2]) ? split(/\s+/, $e->[2]) : ();
        my @upos = defined($e->[3]) ? split(/\s+/, $e->[3]) : ();
        my @xpos = defined($e->[4]) ? split(/\s+/, $e->[4]) : ();
        my @feats = ();
        if(defined($e->[5]))
        {
            my @_feats = split(/\s+/, $e->[5]);
            foreach my $_f (@_feats)
            {
                my @fv = split(/\|/, $_f);
                my %fv;
                foreach my $fv (@fv)
                {
                    next if($fv eq '_');
                    my ($f, $v) = split(/=/, $fv);
                    $fv{$f} = $v;
                }
                push(@feats, \%fv);
            }
        }
        my @deps = split(/\s+/, $e->[6]);
        my @parents;
        my @deprels;
        foreach my $dep (@deps)
        {
            my ($p, $d);
            if($dep =~ m/^(-1|[0-9]+):(.+)$/)
            {
                $p = $1;
                $d = $2;
            }
            else
            {
                log_fatal("Dependency not in form PARENTID:DEPREL");
            }
            if($p < -1 || $p > scalar(@deps))
            {
                log_fatal("Parent index out of range")
            }
            push(@parents, $p);
            push(@deprels, $d);
        }
        push(@fixed_expressions, {'expression' => $expression, 'mode' => $mode, 'forms' => \@forms, 'lemmas' => \@lemmas, 'upos' => \@upos, 'xpos' => \@xpos, 'feats' => \@feats, 'parents' => \@parents, 'deprels' => \@deprels});
    }
}
sub fix_fixed_expressions
{
    my $self = shift;
    my $node = shift;
    ###!!! Hack: The most frequent type is multiword prepositions. There are thousands of them.
    # For now, I am not listing all of them in the table above, but at least they should get ExtPos.
    if($node->deprel() eq 'fixed' && $node->parent()->deprel() eq 'case')
    {
        $node->parent()->iset()->set('extpos', 'adp');
    }
    # Is the current node first word of a known fixed expression?
    my $found_expression;
    foreach my $e (@fixed_expressions)
    {
        my $found = 1;
        my $current_node = $node;
        foreach my $w (@{$e->{forms}})
        {
            if(!defined($current_node) || lc($current_node->form()) ne $w)
            {
                $found = 0;
                last;
            }
            $current_node = $current_node->get_next_node();
        }
        if($found)
        {
            $found_expression = $e;
            last;
        }
    }
    return unless(defined($found_expression));
    # Now we know we have come across one of the known expressions.
    # Get the expression nodes and find a candidate for the external parent.
    my @expression_nodes;
    my @parent_nodes;
    my $current_node = $node;
    foreach my $w (@{$found_expression->{forms}})
    {
        push(@expression_nodes, $current_node);
        push(@parent_nodes, $current_node->parent());
        $current_node = $current_node->get_next_node();
    }
    # If we require for this expression that it already is a catena, check it now.
    if($found_expression->{mode} =~ m/^(catena|subtree|fixed)$/)
    {
        # There must be exactly one member node whose parent is not member.
        my $n_components = 0;
        my $head;
        for(my $i = 0; $i <= $#expression_nodes; $i++)
        {
            my $en = $expression_nodes[$i];
            my $pn = $parent_nodes[$i];
            if(!any {$_ == $pn} (@expression_nodes))
            {
                $n_components++;
                $head = $en;
            }
            else
            {
                # In fixed mode, all inner relations must be 'fixed' or 'punct'.
                if($found_expression->{mode} eq 'fixed' && $en->deprel() !~ m/^(fixed|punct)(:|$)/)
                {
                    my $deprel = $en->deprel();
                    log_warn("Expression '$found_expression->{expression}': Stepping back because of deprel '$deprel', i=$i");
                    return;
                }
            }
        }
        return if($n_components != 1);
        return if($found_expression->{mode} eq 'subtree' && scalar($head->get_descendants({'add_self' => 1})) > scalar(@expression_nodes));
    }
    log_info("Found fixed expression '$found_expression->{expression}'");
    my $parent;
    foreach my $n (@parent_nodes)
    {
        # The first parent node that lies outside the expression will become
        # parent of the whole expression. (Just in case the nodes of the expression
        # did not form a constituent. Normally we expect there is only one parent
        # candidate.) Note that the future parent must not only lie outside the
        # expression, it also must not be dominated by any member of the expression!
        # Otherwise we would be creating a cycle.
        if(!any {$_ == $n || $n->is_descendant_of($_)} (@expression_nodes))
        {
            $parent = $n;
            last;
        }
    }
    log_fatal('Something is wrong. We should have found a parent.') if(!defined($parent));
    # If the expression should indeed be fixed, then the first node should be
    # attached to the parent and all other nodes should be attached to the first
    # node. However, if we are correcting a previously fixed annotation to something
    # non-fixed, there are more possibilities. Therefore we always require the
    # relative addresses of the parents (0 points to the one external parent we
    # identified in the previous section, -1 allows to keep the external parent).
    # Special care needed if the external parent is the artificial root.
    my $subroot_node;
    for(my $i = 0; $i <= $#expression_nodes; $i++)
    {
        $expression_nodes[$i]->set_lemma($found_expression->{lemmas}[$i]) if defined($found_expression->{lemmas}[$i]);
        $expression_nodes[$i]->set_tag($found_expression->{upos}[$i]) if defined($found_expression->{upos}[$i]);
        $expression_nodes[$i]->set_conll_pos($found_expression->{xpos}[$i]) if defined($found_expression->{xpos}[$i]);
        $expression_nodes[$i]->iset()->set_hash($found_expression->{feats}[$i]) if defined($found_expression->{feats}[$i]);
        if($found_expression->{parents}[$i] > 0)
        {
            $expression_nodes[$i]->set_parent($expression_nodes[$found_expression->{parents}[$i]-1]);
            $expression_nodes[$i]->set_deprel($found_expression->{deprels}[$i]);
        }
        elsif($found_expression->{parents}[$i] == -1 && !any {$_ == $parent_nodes[$i]} (@expression_nodes))
        {
            # Do nothing. Keep the current parent, which is already outside the
            # examined expression.
            if($expression_nodes[$i]->parent()->is_root())
            {
                $subroot_node = $expression_nodes[$i];
            }
        }
        elsif($parent->is_root())
        {
            if(defined($subroot_node))
            {
                $expression_nodes[$i]->set_parent($subroot_node);
                $expression_nodes[$i]->set_deprel($found_expression->{deprels}[$i]);
            }
            else
            {
                $expression_nodes[$i]->set_parent($parent);
                $expression_nodes[$i]->set_deprel('root');
                $subroot_node = $expression_nodes[$i];
            }
        }
        else
        {
            $expression_nodes[$i]->set_parent($parent);
            $expression_nodes[$i]->set_deprel($found_expression->{deprels}[$i]);
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
        if($node->deprel() =~ m/^cop(:|$)/ &&
           $node->lemma() =~ m/^(stát|mít|moci|muset|jít|pěstovat|připadat|vyžadovat)$/)
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
# Czech "pokud možno", lit. "if possible", is a multi-word expression that
# functions as an adverb.
#------------------------------------------------------------------------------
sub fix_pokud_mozno
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $lnbr = $node->get_left_neighbor();
    # The expression "pokud možno" ("if possible") functions as an adverb.
    if(lc($node->form()) eq 'možno' && $parent->ord() == $node->ord()-1 &&
       lc($parent->form()) eq 'pokud')
    {
        $node->set_deprel('fixed');
        $parent->set_deprel('advmod');
    }
    elsif(lc($node->form()) eq 'možno' && defined($lnbr) && $lnbr->ord() == $node->ord()-1 &&
          lc($lnbr->form()) eq 'pokud')
    {
        $node->set_parent($lnbr);
        $node->set_deprel('fixed');
        $lnbr->set_deprel('advmod');
    }
}



#------------------------------------------------------------------------------
# Czech "a to/a sice", lit. "and that" ("viz."), is a multi-word expression that
# functions as a conjunction. The second word is tagged as determiner, and PDT
# has several inconsistent annotations for this expression.
#------------------------------------------------------------------------------
sub fix_a_to
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $deprel = $node->deprel();
    my $lnbr = $node->get_left_neighbor();
    my $fixedto;
    # Depending on the original annotation and on the order of processing, "to"
    # may be already attached as 'det', or it may be still 'cc', 'mark' or 'advmod'.
    if($node->form() =~ m/^a$/i && $deprel =~ m/^cc(:|$)/ &&
       $parent->form() =~ m/^(to|sice)$/i && $parent->deprel() =~ m/^(det|cc|mark|advmod|discourse|dep)(:|$)/ && $parent->ord() == $node->ord()+1)
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
        $fixedto = $parent;
        $parent = $grandparent;
    }
    # Sometimes "to" is already attached to "a", and we only change the relation type.
    elsif($node->form() =~ m/^(to|sice)$/i && $deprel =~ m/^(det|cc|mark|advmod|discourse|dep)(:|$)/ &&
          $parent->form() =~ m/^(a)$/i && $parent->ord() == $node->ord()-1)
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
        $fixedto = $node;
    }
    # Occasionally "a" and "to" are attached as siblings rather than one to the other.
    # Note: If "to" was originally attached to "a" and "a" had a functional deprel
    # such as 'cc', "to" was probably reattached to the parent of "a" at the time
    # "a" was being processed. So they are now siblings, too (if we are now looking
    # at "to").
    elsif($node->form() =~ m/^(to|sice)$/i && $deprel =~ m/^(det|cc|mark|advmod|discourse|dep)(:|$)/ && defined($lnbr) &&
          $lnbr->form() =~ m/^(a)$/i && $lnbr->ord() == $node->ord()-1)
    {
        # There is an exception when "a to" are siblings and should stay so.
        # FicTree sent_id = train-laskaneX218-s2
        # text = A to, že jsem jídlo neměla zaplacené, za to také nemohu.
        # The main clause is "za to také nemohu"; the root word is "nemohu" (ord 13).
        # Both "a" and "to" depend on "nemohu". The clause ", že jsem jídlo neměla zaplacené" depends on "to".
        my $ok = 1;
        if($node->ord() == 2 && $node->parent()->ord() == 13)
        {
            my @nodes = $node->get_root()->get_descendants({'ordered' => 1});
            if($nodes[2]->form() eq ',' && $nodes[3]->form() eq 'že')
            {
                $ok = 0;
            }
        }
        if($ok)
        {
            $node->set_parent($lnbr);
            $node->set_deprel('fixed');
            # These occurrences of "to" should be lemmatized as "to" and tagged 'PART'.
            # However, sometimes they are lemmatized as "ten" and tagged 'DET'.
            if(lc($node->form()) eq 'to')
            {
                $node->set_lemma('to');
                $node->set_tag('PART');
                $node->iset()->set_hash({'pos' => 'part'});
            }
            $fixedto = $node;
        }
    }
    # "a tím i" ("and this way also")
    elsif(lc($node->form()) eq 'tím' && $deprel =~ m/^(cc|advmod)(:|$)/)
    {
        $deprel = 'obl';
        $node->set_deprel($deprel);
    }
    # If "to" is now attached as "fixed" (and not as "obl", as in the last branch),
    # it must not have children. They must be reattached to the head of the fixed
    # expression.
    if(defined($fixedto))
    {
        my @children = $fixedto->children();
        foreach my $child (@children)
        {
            $child->set_parent($fixedto->parent());
        }
    }
}



#------------------------------------------------------------------------------
# Czech "to jest", lit. "that is", is a multi-word expression that functions as
# a conjunction. Nevertheless, the two words are still tagged as determiner and
# verb, respectively. PDT does not define any special treatment of multi-word
# expressions, and there are many different annotations of this expression.
#------------------------------------------------------------------------------
sub fix_to_jest
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    my $rnbr = $node->get_right_neighbor();
    my @rsbl = $node->get_siblings({'following_only' => 1});
    # Similar: "to jest/to je/to znamená".
    # Depending on the original annotation and on the order of processing, "to"
    # may be already attached as 'det', or it may be still 'cc' or 'advmod'.
    if($node->form() =~ m/^(to)$/i && $deprel =~ m/^(det|cc|advmod)(:|$)/ && defined($rnbr) &&
       $rnbr->form() =~ m/^(je(st)?|znamená)$/i && $rnbr->deprel() =~ m/^(cc|advmod)(:|$)/)
    {
        my $je = $node->get_right_neighbor();
        $je->set_parent($node);
        $je->set_deprel('fixed');
        # Normalize the attachment of "to" (sometimes it is 'advmod' but it should always be 'cc').
        $deprel = 'cc';
        $node->set_deprel($deprel);
    }
    # If "to jest" is abbreviated and tokenized as "t . j .", the above branch
    # will not catch it.
    elsif(lc($node->form()) eq 't' && $deprel =~ m/^(det|cc|advmod)(:|$)/ &&
          scalar(@rsbl) >= 3 &&
          # following_only implies ordered
          lc($rsbl[0]->form()) eq '.' &&
          lc($rsbl[1]->form()) eq 'j' &&
          lc($rsbl[2]->form()) eq '.')
    {
        $rsbl[0]->set_parent($node);
        $rsbl[0]->set_deprel('punct');
        $rsbl[2]->set_parent($rsbl[1]);
        $rsbl[2]->set_deprel('punct');
        $rsbl[1]->set_parent($node);
        $rsbl[1]->set_deprel('fixed');
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
    my $node = shift;
    my $rnbr = $node->get_right_neighbor();
    if(defined($node->form()) && $node->form() =~ m/^jak$/i && defined($rnbr) &&
       defined($rnbr->form()) && $rnbr->form() =~ m/^známo$/i && $rnbr->ord() == $node->ord()+1)
    {
        my $n0 = $node;
        my $n1 = $rnbr;
        $n0->set_parent($n1);
        $n0->set_deprel('mark');
        $n1->set_deprel('advcl') if(!defined($n1->deprel()) || $n1->deprel() eq 'dep');
        # If the expression is delimited by commas (or hyphens), the commas should be attached to "známo".
        my $lnbr = $n1->get_left_neighbor();
        if(defined($lnbr) && defined($lnbr->form()) && $lnbr->form() =~ m/^[-,]$/)
        {
            $lnbr->set_parent($n1);
            $lnbr->set_deprel('punct');
        }
        $rnbr = $n1->get_right_neighbor();
        if(defined($rnbr) && defined($rnbr->form()) && $rnbr->form() =~ m/^[-,]$/)
        {
            $rnbr->set_parent($n1);
            $rnbr->set_deprel('punct');
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
        # Sanity check: do we have the right sentence and node indices?
        # forint: 12 32 40 49
        if(scalar(@subtree) != 51 ||
           $subtree[12]->form() ne 'forintů' ||
           $subtree[32]->form() ne 'forintů' ||
           $subtree[40]->form() ne 'forintů' ||
           $subtree[49]->form() ne 'forintů')
        {
            log_warn("Bad match in expected sentence: $spanstring");
        }
        else
        {
            # $node is the main verb, "zaplatí".
            # comma dash goods price
            my $c = 0;
            my $d = 1;
            my $g = 2;
            my $p = 3;
            my @conjuncts =
            (
                [13, 14, 16, 19],
                [20, 21, 23, 32],
                [33, 34, 35, 40],
                [41, 42, 44, 49]
            );
            foreach my $conjunct (@conjuncts)
            {
                # The price is the direct object of the missing verb. Promote it.
                $subtree[$conjunct->[$p]]->set_parent($node);
                $subtree[$conjunct->[$p]]->set_deprel('conj');
                # The goods item is the other orphan.
                $subtree[$conjunct->[$g]]->set_parent($subtree[$conjunct->[$p]]);
                $subtree[$conjunct->[$g]]->set_deprel('orphan');
                # Punctuation will be attached to the head of the conjunct, too.
                $subtree[$conjunct->[$c]]->set_parent($subtree[$conjunct->[$p]]);
                $subtree[$conjunct->[$c]]->set_deprel('punct');
                $subtree[$conjunct->[$d]]->set_parent($subtree[$conjunct->[$p]]);
                $subtree[$conjunct->[$d]]->set_deprel('punct');
            }
        }
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
    # "to je nedovedeme-li"
    elsif($spanstring =~ m/^, to je nedovedeme - li/i)
    {
        my @subtree = $self->get_node_subtree($node);
        # "je" is mistagged PRON, should be AUX
        $subtree[2]->set_lemma('být');
        $subtree[2]->set_tag('AUX');
        $subtree[2]->iset()->set_hash({'pos' => 'verb', 'verbform' => 'fin', 'verbtype' => 'aux', 'mood' => 'ind', 'voice' => 'act', 'tense' => 'pres', 'number' => 'sing', 'person' => '3', 'polarity' => 'pos'});
        $subtree[5]->set_parent($subtree[3]);
        $subtree[5]->set_deprel('mark');
    }
    # "ať se již dohodnou jakkoli"
    elsif($spanstring =~ m/^ať již$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        if($subtree[1]->deprel() =~ m/^fixed(:|$)/ && $subtree[1]->ord() >= $subtree[0]->ord()+1)
        {
            $subtree[1]->set_parent($node->parent());
            $subtree[1]->set_deprel('advmod');
        }
    }
    elsif($spanstring =~ m/^Wish You Were Here$/i)
    {
        $node->set_deprel('nmod'); # attached to "album"
    }
    elsif($spanstring =~ m/^Malba I$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('nummod');
    }
    elsif($node->form() =~ m/^že$/i && !$node->parent()->is_root() &&
          $node->parent()->form() =~ m/^možná$/i && $node->parent()->ord() < $node->ord()-1)
    {
        $node->parent()->set_deprel('advmod');
        $node->set_parent($node->parent()->parent());
        $node->set_deprel('mark');
    }
    elsif($spanstring eq 'více než epizodou')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[2]->set_parent($subtree[0]);
        $subtree[2]->set_deprel('obl');
        $subtree[1]->set_parent($subtree[2]);
        $subtree[1]->set_deprel('case');
    }
    elsif($spanstring eq 'pro > ty nahoře')
    {
        my @subtree = $self->get_node_subtree($node);
        # I do not know why there is the ">" symbol here.
        # But since we retagged all ">" to SYM, it cannot be 'punct'.
        $subtree[1]->set_deprel('dep');
    }
    elsif($spanstring eq ', Ekonomická věda a ekonomická reforma , GENNEX & TOP AGENCY , 1991 )')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[10]->set_parent($subtree[2]->parent());
        $subtree[10]->set_deprel('dep');
        $subtree[6]->set_parent($subtree[10]);
        $subtree[7]->set_parent($subtree[10]);
        $subtree[9]->set_parent($subtree[7]);
        $subtree[9]->set_deprel('conj');
        $subtree[8]->set_parent($subtree[9]);
        $subtree[8]->set_deprel('cc');
        $subtree[8]->set_tag('SYM');
        $subtree[8]->iset()->set_hash({'pos' => 'sym'});
    }
    elsif($spanstring =~ m/^, jako jsou např \. na vstřícných svazcích/i)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        $subtree[7]->set_parent($parent);
        $subtree[7]->set_deprel('advcl');
        $subtree[0]->set_parent($subtree[7]);
        $subtree[1]->set_parent($subtree[7]);
        $subtree[1]->set_deprel('mark');
        $subtree[2]->set_parent($subtree[7]);
        $subtree[2]->set_deprel('cop');
        $subtree[2]->set_tag('AUX');
        $subtree[2]->iset()->set('verbtype' => 'aux');
        $subtree[5]->set_parent($subtree[7]);
        $subtree[5]->set_deprel('case');
    }
    # Tohle by měl být schopen řešit blok Punctuation, ale nezvládá to.
    elsif($spanstring =~ m/^\( podle vysoké účasti folkových písničkářů a skupin .*\) ,$/)
    {
        my @subtree = $self->get_node_subtree($node);
        my $parent = $node->parent();
        # Neprojektivně zavěšená čárka za závorkou.
        $subtree[22]->set_parent($parent);
    }
    elsif($spanstring eq 'Větev A')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('nmod');
    }
    elsif($spanstring eq 'VADO MA DOVE ?')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[0]->set_deprel('xcomp');
    }
    elsif($spanstring eq 'Časy Oldřicha Nového jsou ty tam , ale snímání obrazů prožívá renesanci .')
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[4]->set_parent($node->parent());
        $subtree[4]->set_deprel('root');
        $subtree[0]->set_parent($subtree[4]);
        $subtree[0]->set_deprel('nsubj');
        $subtree[3]->set_parent($subtree[4]);
        $subtree[3]->set_deprel('cop');
        $subtree[3]->set_tag('AUX');
        $subtree[3]->iset()->set('verbtype' => 'aux');
        $subtree[5]->set_parent($subtree[4]);
        $subtree[5]->set_deprel('fixed');
        $subtree[10]->set_parent($subtree[4]);
        $subtree[10]->set_deprel('conj');
        $subtree[12]->set_parent($subtree[4]);
    }
    # "dílem" as paired conjunction (but tagged NOUN)
    # Lemma in the data is "dílo" but it should be "díl".
    # And maybe we really want to say that it is a grammaticalized conjunction.
    # If not, it cannot be 'cc'. Then it is probably 'obl' or 'nmod'.
    elsif($node->form() =~ m/^dílem$/i && $node->is_noun() && $node->deprel() =~ m/^cc(:|$)/)
    {
        $node->set_deprel('nmod');
    }
    elsif($spanstring =~ m/^jako u mrtvol nebo utopených/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[2]->set_parent($node->parent());
        $subtree[2]->set_deprel('obl');
        $subtree[0]->set_parent($subtree[2]);
        $subtree[0]->set_deprel('case');
    }
    elsif($spanstring =~ m/^, nemohl - li by být rozpočet sice vyrovnaný , přesto však štíhlejší$/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[7]->set_deprel('cc');
        $subtree[9]->set_parent($subtree[12]);
        $subtree[11]->set_parent($subtree[12]);
        $subtree[11]->set_deprel('cc');
    }
    # The following annotation errors have been found in Czech FicTree.
    elsif($spanstring =~ m/^neboť to , co ho tak slastně nadýmalo , byla smrt ;$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_parent($node->parent());
        $subtree[1]->set_deprel('root');
        $subtree[0]->set_parent($subtree[1]);
        $subtree[9]->set_parent($subtree[1]);
        $subtree[9]->set_deprel('cop');
        $subtree[9]->iset()->set('verbtype' => 'aux');
        $subtree[9]->set_tag('AUX');
        $subtree[10]->set_parent($subtree[1]);
        $subtree[11]->set_parent($subtree[1]);
    }
    elsif($spanstring =~ m/^, jako by bylo tělo ztraceno$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[5]->set_parent($node->parent());
        $subtree[5]->set_deprel($node->deprel());
        $subtree[0]->set_parent($subtree[5]);
        $subtree[1]->set_parent($subtree[5]);
        $subtree[2]->set_parent($subtree[5]);
        $subtree[3]->set_parent($subtree[5]);
        $subtree[3]->set_deprel('aux:pass');
        $subtree[3]->iset()->set('verbtype' => 'aux');
        $subtree[3]->set_tag('AUX');
        $subtree[4]->set_parent($subtree[5]);
    }
    elsif($node->form() eq 'by' && $node->deprel() =~ m/^expl(:|$)/)
    {
        $node->set_deprel('aux');
        $node->iset()->set('verbtype' => 'aux');
        $node->set_tag('AUX');
    }
    elsif($spanstring =~ m/^" a když by \? " řekla dívka \.$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[2]->set_parent($subtree[6]);
        $subtree[2]->set_deprel('ccomp');
        $subtree[1]->set_parent($subtree[2]);
        $subtree[1]->set_deprel('cc');
        $subtree[3]->set_parent($subtree[2]);
        $subtree[3]->set_deprel('aux');
        $subtree[4]->set_parent($subtree[2]);
    }
    elsif($spanstring =~ m/^" ten budeš mít , když mě neposlechneš ! " ukončila jsem rozmluvu/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[0]->set_parent($subtree[3]);
        $subtree[9]->set_parent($subtree[3]);
    }
    elsif($spanstring =~ m/^" Jednou mi ujel vlak , " vyprávěl J \. M \. , " kterým jsem nutně potřeboval odjet \.$/i) #"
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[12]->set_parent($subtree[14]);
        $subtree[13]->set_parent($subtree[14]);
    }
    elsif($spanstring =~ m/^Konec pravopisných bojů \( \? \)$/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[4]->set_parent($subtree[0]);
        $subtree[3]->set_parent($subtree[4]);
        $subtree[5]->set_parent($subtree[4]);
    }
    elsif($spanstring =~ m/^My , národ slovenský , \. \. \. společně/)
    {
        my @subtree = $self->get_node_subtree($node);
        if(scalar(@subtree)>=25 && $subtree[24]->form() eq ',')
        {
            $subtree[21]->set_parent($subtree[0]);
            $subtree[22]->set_parent($subtree[0]);
            $subtree[23]->set_parent($subtree[0]);
        }
    }
    # The following annotation errors have been found in Czech CAC.
    elsif($spanstring =~ m/mnohý z nich v sobě určitou naději živí , ale jen několik vyvolených může být o své síle přesvědčeno/i)
    {
        # Two previous nodes, "Možná" and "," are also attached to the root.
        my $root = $node->get_root();
        my @subtree = $root->get_descendants({'ordered' => 1});
        if($subtree[0]->form() =~ m/^možná$/i && $subtree[1]->form() eq ',' && $#subtree >= 22 && $subtree[22]->form() eq '.')
        {
            $subtree[0]->set_parent($root);
            $subtree[0]->set_deprel('root');
            $subtree[10]->set_parent($subtree[0]);
            $subtree[10]->set_deprel('csubj');
            $subtree[1]->set_parent($subtree[10]);
            $subtree[1]->set_deprel('punct');
            $subtree[2]->set_parent($subtree[10]);
            $subtree[2]->set_deprel('mark');
            # Reattach the final period from "že" to "Možná".
            $subtree[22]->set_parent($subtree[0]);
            $subtree[22]->set_deprel('punct');
        }
    }
    # CAC train s62w-s128
    elsif($spanstring =~ m/, do které se na přimísí asi/i)
    {
        my @subtree = $self->get_node_subtree($node);
        # Missing noun after the preposition "na". The preposition should be
        # promoted as the head of an "obl" phrase. It should not be "case" or "mark".
        $subtree[4]->set_deprel('obl');
    }
    # PDT-C train-l lnd94104-111-p1s1
    elsif($spanstring =~ m/Tenis ad - Hamburk První kolo :/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('conj');
        $subtree[3]->set_deprel('parataxis');
        $subtree[5]->set_deprel('parataxis');
    }
    # FicTree test test-ku_smlas062-s14
    elsif($spanstring =~ m/^, že chtěla opravdu zemřít$/i)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[3]->set_parent($subtree[2]);
        $subtree[3]->set_deprel('advmod');
    }
    # CAC train a03w-s91
    elsif($spanstring =~ m/^, zejména jde - li o práce/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[1]->set_deprel('advmod');
        $subtree[3]->set_parent($subtree[4]);
        $subtree[4]->set_parent($subtree[2]);
        $subtree[4]->set_deprel('mark');
    }
    # CAC train n38w-s158
    elsif($spanstring =~ m/^a jedná - li podvědomě ,/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[0]->set_deprel('cc');
        $subtree[2]->set_parent($subtree[3]);
        $subtree[3]->set_parent($subtree[1]);
        $subtree[3]->set_deprel('mark');
    }
    # CAC train s08w-s34
    elsif($spanstring =~ m/^, i v poměru k výrobě oceli ,/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[3]->set_parent($subtree[2]);
        $subtree[3]->set_deprel('fixed');
        $subtree[4]->set_parent($subtree[2]);
        $subtree[4]->set_deprel('fixed');
    }
    # CAC train s24w-s90
    elsif($spanstring =~ m/^, ba dokonce až i k skeptickým názorům/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[3]->set_deprel('cc');
        $subtree[5]->set_parent($subtree[7]);
        $subtree[5]->set_deprel('case');
    }
    # CAC train s27w-s3
    elsif($spanstring =~ m/^, a to ve spolupráci s matematiky/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[4]->set_parent($subtree[3]);
        $subtree[4]->set_deprel('fixed');
    }
    # CAC train s68w-s159
    elsif($spanstring =~ m/^a značíme je velkými písmeny na rozdíl od malých písmen/)
    {
        my @subtree = $self->get_node_subtree($node);
        $subtree[9]->set_parent($subtree[1]);
        $subtree[9]->set_deprel('obl');
        $subtree[5]->set_parent($subtree[9]);
        $subtree[5]->set_deprel('case');
        $subtree[6]->set_parent($subtree[5]);
        $subtree[6]->set_deprel('fixed');
        $subtree[7]->set_parent($subtree[5]);
        $subtree[7]->set_deprel('fixed');
    }
    # Make sure that no node has more than one subject. This is to prevent
    # validation errors in UD. However, instead of randomly picking a subject
    # and re-labeling it as dep, we should investigate and fix the error
    # upstream.
    my @children = $node->get_children({'ordered' => 1});
    if(scalar(@children) >= 2)
    {
        my $ns = 0;
        foreach my $child (@children)
        {
            if($child->deprel() =~ m/^[nc]subj(:|$)/)
            {
                $ns++;
                if($ns > 1)
                {
                    $child->set_deprel('dep');
                }
            }
        }
        if($ns > 1)
        {
            log_warn("Node '".$node->form()."' has $ns subjects.");
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::FixUD

Czech-specific post-processing after the treebank has been converted from the
Prague style to Universal Dependencies. It can also be used to check for and
fix errors in treebanks that were annotated directly in UD.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
