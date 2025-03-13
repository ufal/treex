package Treex::Block::HamleDT::CS::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    # This default is now (2021) dangerous, as different Prague treebanks use different, incompatible tagsets!
    # PDT (now taken from the newest version, PDT-C) uses cs::pdtc.
    # CAC, CLTT, FicTree and PUD still use cs::pdt.
    # The safe solution: In the HamleDT Makefile of each treebank, specify the harmonize block together with the iset_driver parameter.
    # PDT:     HARMONIZE=HarmonizePDTC iset_driver=cs::pdtc
    # CAC:     HARMONIZE=HarmonizePDT iset_driver=cs::pdt
    # FicTree: HARMONIZE=HarmonizeFicTree
    default       => 'cs::pdt',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

has change_bundle_id => (is=>'ro', isa=>'Bool', default=>1, documentation=>'use id of a-tree roots as the bundle id');



#------------------------------------------------------------------------------
# This block is specific to the Czech language and to the PDT family of
# treebanks but not to a particular treebank (and its flavor of the guidelines).
# Most functions defined in this block are actually called from SUPER::
# process_zone() (the functions are foreseen but have language-specific content).
# Functions that are not foreseen globally are typically specific to just one
# treebank and thus implemented in blocks derived from this one. The little
# that remains inbetween is called from here, after the foreseen functions have
# been called from SUPER, and before the treebank-specific functions will be
# called from derived classes.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Fix a rare combination of preposition and subordinated clause in copula predication.
    $self->fix_byt_pro_aby($root);
    return $root;
}



#------------------------------------------------------------------------------
# This function targets a rare construction observed in Czech (and specifically
# in PDT-C 2.0). It is possible that similar constructions occur in other
# languages but the function must be language-specific because it needs to
# operate on selected lemmas only. The Czech example is "byl by pro, abychom
# dělali X" = "he would be for (it) that we do X". Here "byl by" is a conditi-
# onal copula and the rest (including the nested clause) is a predicate.
# Nevertheless, the afun Pnom for nominal predicates is not present; instead,
# the preposition "pro" has AuxP, its child "abychom" has AuxC, and the verb
# under "abychom" has Adv because it is an adverbial clause. We will replace
# the AuxP of "pro" with Pnom. It will address two issues that would otherwise
# occur when moving to UD: The nominal predicate with copula would not be
# recognized, and the preposition would be treated as another marker (besides
# "abychom") of the subordinate clause.
#------------------------------------------------------------------------------
sub fix_byt_pro_aby
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # We only want to do this if the parent is the copula "být". And we
        # cannot recognize the copula other than by looking at its lemma.
        # We should also look at the lemma of the current node (preposition)
        # because we do not mess up the compound conjunction "místo aby",
        # regardless whether it depends on a copula or on a normal verb.
        if($node->deprel() eq 'AuxP' && $node->parent()->is_verb())
        {
            my $lemma = $node->lemma() // '';
            my $plemma = $node->parent()->lemma() // '';
            if($plemma eq 'být' && $lemma =~ m/^(pro|proti)$/)
            {
                my @children = $node->children();
                if(scalar(@children) == 1 && $children[0]->deprel() eq 'AuxC')
                {
                    $node->set_deprel('Pnom');
                }
            }
        }
    }
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
    return $node->tag();
}



#------------------------------------------------------------------------------
# Adds Interset features that cannot be decoded from the PDT tags but they can
# be inferred from lemmas and word forms. This method is called from
# SUPER->process_zone().
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    # We must first normalize the lemmas because many subsequent rules depend on them.
    $self->remove_features_from_lemmas($root);
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        # Fix Interset features of pronominal words.
        if($node->is_pronominal())
        {
            # In one case in FicTree, "si" is mistakenly lemmatized as "být"
            # (i.e., colloquial form of "jsi"), but it is still tagged correctly
            # as a reflexive pronoun.
            if($form eq 'si' && $lemma eq 'být')
            {
                $lemma = 'se';
                $node->set_lemma($lemma);
            }
            # In the Prague treebanks until PDT 3.5, plural personal pronouns had a singular lemma,
            # not only in the third person but also in the first and second ('my' --> 'já'). In PDT-C
            # this was changed but it would create an inconsistency with other Czech treebanks, so
            # let's change it back here.
            if($node->is_personal_pronoun())
            {
                if($lemma eq 'my')
                {
                    $lemma = 'já';
                }
                elsif($lemma eq 'vy')
                {
                    $lemma = 'ty';
                }
                # DZ: To me, the possessive pronouns are more controversial because their lemmatization
                # should be analogous to adjectives, and that would not include 'náš' --> 'můj'.
                # However, the older data did this, too.
                elsif($lemma eq 'náš')
                {
                    $lemma = 'můj';
                }
                elsif($lemma eq 'váš')
                {
                    $lemma = 'tvůj';
                }
            }
            # Some instances of possessive relative pronouns in CAC are wrongly lemmatized to the
            # non-possessive "jenž". We have to fix it because some subsequent operations are
            # designed for "jenž" but not for the possessives; in addition, some morphological
            # features are not allowed for non-possessive pronouns.
            # Note that "jehož" can be also the genitive form of "jenž" in non-possessive contexts,
            # so we must look at morphological features. In contrast, "jejíž" and "jejichž" are
            # unambiguous, the corresponding genitives would be "jíž/níž" and "jichž/nichž".
            if($lemma eq 'jenž')
            {
                if($form =~ m/^jehož$/i && $node->is_possessive())
                {
                    $lemma = 'jehož';
                    $node->set_lemma($lemma);
                }
                elsif($form =~ m/^(jejíž|jejíhož|jejímuž|jejímž|jejíchž|jejímiž)$/i)
                {
                    $lemma = 'jejíž';
                    $node->set_lemma($lemma);
                }
                elsif($form =~ m/^jejichž$/i)
                {
                    $lemma = 'jejichž';
                    $node->set_lemma($lemma);
                }
            }
            # In the old cs::pdt tagset, third-person pronouns had a feature that distinguished their
            # bare form (without preposition: "je") and form with preposition ("ně"). In the new cs::pdtc
            # tagset, this distinction is lost but we can re-introduce it here.
            if($lemma =~ m/^(on|jenž)$/ && $node->iset()->case() =~ m/(gen|dat|acc|loc|ins)/)
            {
                if($form =~ m/^(jeho|jej|jemu|jím|jí|ji|jich|jim|je|jimi)ž?$/i)
                {
                    $node->iset()->set('prepcase', 'npr');
                }
                elsif($form =~ m/^(něho|něj|němu|něm|ním|ní|ni|nich|nim|ně|nimi)ž?$/i)
                {
                    $node->iset()->set('prepcase', 'pre');
                }
            }
            # In the old cs::pdt tagset, the relative pronoun 'jenž' had its own tag.
            # In the new cs::pdtc tagset, it is conflated with relative determiners 'jaký', 'který', 'čí'.
            # Distinguish them here.
            if($lemma eq 'jenž')
            {
                $node->iset()->set('pos', 'noun');
                $node->iset()->set('prontype', 'rel');
            }
            # Indefinite pronouns and determiners cannot be distinguished by their PDT tag (PZ*).
            if($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|málo|sotva)?(kdo|cos?)(si|koliv?)?|nikdo|nic|nihil|nothing)$/)
            {
                $node->iset()->set('pos', 'noun');
                # In the old cs::pdt tagset, derivates of 'kdo' and 'co' were marked for animacy.
                # In the new cs::pdtc tagset, this distinction is lost but we can re-introduce it here.
                if($lemma =~ m/^kdo/ || $lemma =~ m/kdo$/)
                {
                    $node->iset()->set('animacy', 'anim');
                }
                elsif($lemma =~ m/^co/ || $lemma =~ m/co$/)
                {
                    $node->iset()->set('animacy', 'inan');
                }
            }
            elsif($lemma =~ m/(^(jaký|který)|(jaký|který)$|^(každý|všechen|sám|samý|žádný|some|takýs)$)/)
            {
                $node->iset()->set('pos', 'adj');
            }
            # Pronouns čí, něčí, čísi, číkoli, ledačí, kdečí, bůhvíčí, nevímčí, ničí should have Poss=Yes.
            elsif($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|ni)?čí|čí(si|koliv?))$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('poss', 'poss');
            }
            # Pronoun (determiner) "sám" is difficult to classify in the traditional Czech system but in UD v2 we now have the prontype=emp, which is quite suitable.
            # Note that PDT assigns the long forms to a different lemma, "samý", but there is an overlap in meanings and we should probably merge the two lexemes.
            if($lemma =~ m/^(sám|samý)$/)
            {
                # Long forms: samý|samá|samé|samí|samého|samou|samému|samém|samým|samých|samými
                # Short forms: sám|sama|samo|sami|samy|samu
                # Mark the short forms with the variant feature and then unify the lemma.
                if($form =~ m/^(sám|sama|samo|sami|samy|samu)$/i)
                {
                    $node->iset()->set('variant', 'short');
                }
                $lemma = 'samý';
                $node->set_lemma($lemma);
                $node->iset()->set('prontype', 'emp');
            }
            # Pronominal numerals are all treated as combined demonstrative and indefinite, because the PDT tag is only one.
            # But we can distinguish them by the lemma.
            if($lemma =~ m/^kolikráte?$/)
            {
                $node->iset()->set('prontype', 'int|rel');
            }
            elsif($lemma =~ m/^((po)?((ně|kdoví|bůhví|nevím)kolik|(ne|pře)?(mnoho|málo)|(nej)?(více?|méně|míň)|moc|mó+c|hodně|bezpočtu|nespočet|nesčíslně)(átý|áté|erý|ero|k?ráte?)?)$/)
            {
                $node->iset()->set('prontype', 'ind');
            }
            elsif($lemma =~ m/^tolik(ráte?)?$/)
            {
                $node->iset()->set('prontype', 'dem');
            }
        }
        # Jan Hajič's morphological analyzer tags "každý" simply as adjective (hence we did not catch it in the above branch),
        # but it is an attributive pronoun, according to the Czech grammar.
        if($lemma eq 'každý')
        {
            $node->iset()->set('pos', 'adj');
            $node->iset()->set('prontype', 'tot');
            ###!!! This does not change the PDT tag (which may become XPOS in UD), which stays adjectival, e.g. AAMS1----1A----. Do we want to change it too?
        }
        # The relative pronoun "kterážto" (lemma "kterýžto") has the tag PJFS1----------, which leads to (wrongly) setting PrepCase=Npr,
        # because otherwise the PJ* tags are used for the various non-prepositional forms of "jenž".
        if($lemma eq 'kterýžto')
        {
            $node->iset()->clear('prepcase');
        }
        # Pronominal adverbs.
        if($node->is_adverb())
        {
            if($lemma =~ m/^(kde|kam|odkud|kudy|kdy|odkdy|dokdy|jak|proč)$/)
            {
                $node->iset()->set('prontype', 'int|rel');
            }
            elsif($lemma =~ m/^((ně|ledas?|málo|kde|bůhví|nevím)(kde|kam|kudy|kdy|jak)|(od|do)ně(kud|kdy)|(kde|kam|odkud|kudy|kdy|jak)(si|koliv?))$/)
            {
                $node->iset()->set('prontype', 'ind');
            }
            elsif($lemma =~ m/^(tady|zde|tu|tam|tamhle|onam|odsud|odtud|odtamtud|teď|nyní|tehdy|tentokráte?|tenkráte?|odtehdy|dotehdy|dosud|tak|proto)$/)
            {
                $node->iset()->set('prontype', 'dem');
            }
            elsif($lemma =~ m/^(všude|odevšad|všudy|vždy|odevždy|odjakživa|navždy)$/)
            {
                $node->iset()->set('prontype', 'tot');
            }
            elsif($lemma =~ m/^(nikde|nikam|odnikud|nikudy|nikdy|odnikdy|donikdy|nijak)$/)
            {
                $node->iset()->set('prontype', 'neg');
            }
        }
        # Mark the verb 'být' as auxiliary regardless of context. In most contexts,
        # it is at least a copula (AUX in UD). Only in purely existential sentences
        # (without location) it will be the root of the sentence. But it is not
        # necessary to change the tag to VERB in these contexts. The tree structure
        # will contain the necessary information.
        if($lemma =~ m/^(být|bývat|bývávat)$/)
        {
            $node->iset()->set('verbtype', 'aux');
        }
        # Passive participles should be adjectives both in their short (predicative)
        # and long (attributive) form. Now the long forms are adjectives and short
        # forms are verbs (while the same dichotomy of non-verbal adjectives, such as
        # starý-stár, is kept within adjectives).
        if($node->is_verb() && $node->is_participle() && $node->iset()->is_passive())
        {
            $node->iset()->set('pos', 'adj');
            $node->iset()->set('variant', 'short');
            # Before changing the lemma from the infinitive to the participle, copy the old lemma to the LDeriv attribute in MISC.
            # LDeriv may already exist if the verb itself is derived. If that's the case, overwrite it.
            my $lemma = $node->lemma();
            if(defined($lemma))
            {
                $node->set_misc_attr('LDeriv', $lemma);
            }
            # That was the easy part. But we must also change the lemma.
            # nést-nesen-nesený, brát-brán-braný, mazat-mazán-mazaný, péci-pečen-pečený, zavřít-zavřen-zavřený, tisknout-tištěn-tištěný, minout-minut-minutý, začít-začat-začatý,
            # krýt-kryt-krytý, kupovat-kupován-kupovaný, prosit-prošen-prošený, trpět-trpěn-trpěný, sázet-sázen-sázený, dělat-dělán-dělaný
            my $form = lc($node->form());
            # Remove gender/number morpheme if present.
            $form =~ s/[aoiy]$//;
            # Stem vowel change "á" to "a".
            $form =~ s/án$/an/;
            # Add the ending of masculine singular nominative long adjectives.
            $form .= 'ý';
            $node->set_lemma($form);
        }
    }
}



#------------------------------------------------------------------------------
# Guesses gender and number of converbs. This is not needed in data from the
# Czech National Corpus (e.g., FicTree) where this has been disambiguated
# manually. However, data from ÚFAL use ambiguous tags and we have to
# disambiguate them heuristically here to make the annotations converge. We can
# use the tree structure and look for the subject.
#
# This method should be called at the end of fix_morphology() but it is not
# called by default. Derived blocks that need it should redefine fix_morphology(),
# call its default (SUPER) version first and then call guess_converb_gender().
#------------------------------------------------------------------------------
sub guess_converb_gender
{
    my $self = shift;
    my $node = shift;
    # Converbs have one common form (-c/-i) for singular feminines and neuters
    # (this holds in Modern Czech; in Old Czech, neuters used the masculine
    # form instead): "dělajíc", "udělavši".
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
                my @siblings = $parent->get_echildren();
                if(any {my $d = $_->deprel() // $_->afun(); defined($d) && $d =~ m/^Sb/ && $_->is_neuter() && !$_->is_feminine() && $_ != $node} (@siblings))
                {
                    $neuter = 1;
                }
            }
        }
        if($neuter)
        {
            $node->iset()->set('number', 'sing');
            $node->iset()->set('gender', 'neut');
        }
        else
        {
            $node->iset()->set('number', 'sing');
            $node->iset()->set('gender', 'fem');
        }
        $self->set_pdt_tag($node);
        $node->set_conll_pos($node->tag());
    }
}



#------------------------------------------------------------------------------
# Lemmas in PDT often contain codes of additional features. Move at least some
# of these features elsewhere. (Note that this is specific to Czech lemmas.
# Lemmas in the other Prague treebanks are different.)
#------------------------------------------------------------------------------
sub remove_features_from_lemmas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my %nametags =
    (
        # given name: Jan, Jiří, Václav, Petr, Josef
        'Y' => 'giv',
        # family name: Klaus, Havel, Němec, Jelcin, Svoboda
        'S' => 'sur',
        # nationality: Němec, Čech, Srb, Američan, Slovák
        'E' => 'nat',
        # location: Praha, ČR, Evropa, Německo, Brno
        'G' => 'geo',
        # organization: ODS, OSN, Sparta, ODA, Slavia
        'K' => 'com',
        # product: LN, Mercedes, Tatra, PC, MF
        'R' => 'pro',
        # other: US, PVP, Prix, Rapaport, Tour
        'm' => 'oth'
    );
    # The terminology (field) tags are not used consistently.
    # We could propose a new Interset feature to preserve them (at present it is possible to mix them with name types but I do not like it)
    # but in the current state of the annotation it is probably better to drop them completely.
    # _;[HULjgcybuwpzo]
    my %termtags =
    (
        # chemistry: H: CO, ftalát, pyrolyzát, adenozintrifosfát, CFC
        # medicine: U: AIDS, HIV, neschopnost, antibiotikum, EEG
        # natural sciences: L: HIV, neem, Homo, Buthidae, čipmank
        # justice: j: Sb, neschopnost
        # technology in general: g: ABS
        # computers and electronics: c: SPT, CD, Microsoft, MS, ROM
        # hobby, leisure, traveling: y: CD, CNN, MTV, DP, CHKO
        # economy, finance: b: dolar, ČNB, DEM, DPH, MF
        # culture, education, arts, other sciences: u: CD, AV, MK, MŠMT, proměnná
        # sports: w: MS, NHL, ME, Cup, UEFA
        # politics, government, military: p: ODS, ODA, ČSSD, EU, ČSL
        # ecology, environment: z: MŽP, CHKO
        # color indication: o: červený, infračervený, fialový, červeno
    );
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        next if(!defined($lemma));
        my $iset = $node->iset();
        my $wild = $node->wild();
        # The underscore character is used to delimit various additional tags within
        # the lemma string. If the character occurs in the underlying text (which
        # probably never happens in PDT), its lemma is '_' without any extra tags.
        if($lemma =~ m/^_.+$/)
        {
            log_warn("Lemma '$lemma' starts with the underscore character but it is followed by other characters.");
        }
        elsif($lemma ne '_')
        {
            my $lprop = $lemma;
            my $ltags = '';
            if($lemma =~ m/^([^_]+)(_.*)$/)
            {
                $lprop = $1;
                $ltags = $2;
                # Occasionally there is an error and two underscores occur in sequence:
                # l-5__,t_^(př._l'Arc,_stažený_tvar_fr._členu)
                $ltags =~ s/_+/_/g;
            }
            # Verb lemmas encode aspect.
            # Aspect is a lexical feature in Czech but it can still be encoded in Interset and not in the lemma.
            if($ltags =~ s/_:T_:W// || $ltags =~ s/_:W_:T//)
            {
                # Do nothing. The verb can have any of the two aspects so it does not make sense to say anything about it.
                # (But there are also many verbs that do not have any information about their aspect, probably due to incomplete lexicon.)
            }
            elsif($ltags =~ s/_:T//)
            {
                $iset->set('aspect', 'imp');
            }
            elsif($ltags =~ s/_:W//)
            {
                $iset->set('aspect', 'perf');
            }
            # Move the abbreviation feature from the lemma to the Interset features.
            # It is probably not necessary because the same information is also encoded in the morphological tag.
            if($ltags =~ s/_:B//)
            {
                $iset->set('abbr', 'abbr');
            }
            # According to the documentation in http://ufal.mff.cuni.cz/techrep/tr27.pdf, lemmas may also encode the part of speech:
            # _:[NAJZMVDPCIFQX]
            # However, none of these codes actually appears in PDT 3.0 data.
            # According to the documentation in http://ufal.mff.cuni.cz/techrep/tr27.pdf, lemmas may also encode style:
            # _,[tnashelvx]
            # It is not necessarily the same thing as the style in inflection.
            # For instance, "zelenej" is a colloquial form of a neutral lemma "zelený".
            # However, "zpackaný" is a colloquial lemma, regardless whether the form is "zpackaný" (neutral) or "zpackanej" (colloquial).
            # Move the foreign feature from the lemma to the Interset features.
            # There is an error and once the foreign flag is rendered as ;t instead of ,t:
            # Johnnie_;R_;S_;t
            if($ltags =~ s/_[,;]t//)
            {
                $iset->set('foreign', 'foreign');
            }
            # Vernacular (dialect)
            if($ltags =~ s/_,n//)
            {
                # Examples: súdit, husličky
                $iset->set('style', 'vrnc');
            }
            # The style flat _,a means "archaic" but it seems to be used inconsistently in the data. Discard it.
            # The style flat _,s means "bookish" but it seems to be used inconsistently in the data. Discard it.
            # On one occasion both of them are used: nikdá_,a_,s
            $ltags =~ s/_,[as]//g;
            # Colloquial
            if($ltags =~ s/_,h//)
            {
                # Examples: vejstraha, bichle
                $iset->set('style', 'coll');
            }
            # Expressive
            if($ltags =~ s/_,e//)
            {
                # Examples: miminko, hovínko
                $iset->set('style', 'expr');
            }
            # Slang, argot
            if($ltags =~ s/_,l//)
            {
                # Examples: mukl, děcák, pécéčko
                $iset->set('style', 'slng');
            }
            # Vulgar
            if($ltags =~ s/_,v//)
            {
                # Examples: parchant, bordelový
                $iset->set('style', 'vulg');
            }
            # The style flag _,x means, according to documentation, "outdated spelling or misspelling".
            # But it occurs with a number of alternative spellings and sometimes it is debatable whether
            # they are outdated, e.g. "patriotismus" vs. "patriotizmus".
            if($ltags =~ s/_,x//)
            {
                # According to documentation in http://ufal.mff.cuni.cz/techrep/tr27.pdf,
                # 2 means "variant, rarely used, bookish, or archaic".
                $iset->set('variant', '2');
                $iset->set('style', 'rare');
            }
            # The style flag _,i is new in PDT-C (January 2021) and means "distortion, typo".
            # http://ufal.mff.cuni.cz/pdt-c/publications/TR_PDT_C_morph_manual.pdf, Section 4.2.3, page 14
            # It is typically accompanied by a comment that shows the standard form: rozpočed_,i_^(^DS**rozpočet)
            if($ltags =~ s/_,i//)
            {
                $iset->set('typo', 'yes');
            }
            # Term categories encode (among others) types of named entities.
            # There may be two categories at one lemma.
            # JVC_;K_;R (buď továrna, nebo výrobek)
            # Poldi_;Y_;K
            # Kladno_;G_;K
            my %nametypes;
            while($ltags =~ s/_;([YSEGKRm])//)
            {
                my $tag = $1;
                my $nt = $nametags{$tag};
                if(defined($nt))
                {
                    $nametypes{$nt}++;
                }
            }
            # Drop the other term categories because they are used inconsistently (see above).
            $ltags =~ s/_;[HULjgcybuwpzo]//g;
            my @nametypes = sort(keys(%nametypes));
            if(@nametypes)
            {
                $iset->set('nametype', join('|', @nametypes));
                if($node->is_noun())
                {
                    $iset->set('nountype', 'prop');
                }
            }
            elsif($node->is_noun() && !$node->is_pronoun() && $iset->nountype() eq '')
            {
                $iset->set('nountype', 'com');
            }
            # Lemma comments help explain the meaning of the lemma.
            # They are especially useful for homonyms, foreign words and abbreviations; but they may appear everywhere.
            my $lgloss = '';
            my $lderiv = '';
            my $lcorrect = '';
            # A typical comment is a synonym or other explaining text in Czech.
            # Example: jen-1_^(pouze)
            # Unfortunately there are instances where the '^' character is missing. Let's capture them as well.
            # Example: správně_(*1ý)
            # Unfortunately there are instances where the closing ')' is missing. Let's capture them as well.
            # Example: and-1_,t_^(obv._souč._anglických_názvů,_"a"
            # Regular expression for a non-left-bracket.
            my $nonbrack = '[^\)]';
            while($ltags =~ s/_\^?(\($nonbrack+\)?)//)
            {
                my $comment = $1;
                # Add the closing bracket if missing. ((
                $comment .= ')' if($comment !~ m/\)$/);
                # There is a special class of comments that encode how this lemma was derived from another lemma.
                # Example: uváděný_^(*2t)
                # An oddity: Maruška_^(^DI*4ie-1)
                if($comment =~ m/^\((?:\^DI)?\*(\d*)(.*)\)$/)
                {
                    my $nrm = $1;
                    my $add = $2;
                    if(defined($nrm) && $nrm > 0)
                    {
                        # Remove the specified number of trailing characters.
                        # Warning: If there was the numeric lemma id suffix, it is counted in the characters removed!
                        # pozornost-1_^(všímavý,_milý,_soustředěný)_(*5ý-1)
                        # 5 characters from "pozornost-1" = "pozorn" + "ý-1"
                        # if we wrongly remove them from "pozornost", the result will be "pozoý-1"
                        # Similarly, if the lemma proper includes a reference to a synonymous lemma or a numeric value, it is counted in the characters removed.
                        # šestina`6_^(*5`6)
                        # The lemma this is derived from is "šest`6".
                        $lderiv = $lprop;
                        $lderiv =~ s/.{$nrm}$//;
                        # Append the original suffix.
                        $lderiv .= $add if(defined($add));
                        # But if it includes its own lemma identification number, remove it again.
                        $lderiv =~ s/(.)-(\d+)/$1/;
                        # If it includes its own reference to another lemma or numeric value, remove it too.
                        $lderiv =~ s/(.)`.+/$1/; # `
                        if($lderiv eq $lprop)
                        {
                            log_warn("Lemma '$lemma', derivation comment '$comment', no change.");
                            $lderiv = '';
                        }
                        # Identify passive deverbative adjectives (participles).
                        # They could have the VerbForm feature in UD but the PDT
                        # tags do not identify them as a distinct subclass.
                        # (In contrast, the PDT tags do distinguish active participles
                        # such as "dělající", "udělavší".)
                        # Exclude derivations of the type "-elný", those are not passives.
                        elsif($lderiv =~ m/(t|ci)$/ && $lprop =~ m/[^l][nt]ý$/ && $iset->is_adjective())
                        {
                            $iset->set('verbform', 'part');
                            $iset->set('voice', 'pass');
                        }
                        # Identify deverbative nouns. They could have the VerbForm feature
                        # in UD but the PDT tags do not identify them as a distinct subclass.
                        elsif($lderiv =~ m/(t|ci)$/ && $lprop =~ m/[nt]í$/ && $iset->is_noun())
                        {
                            $iset->set('verbform', 'vnoun');
                        }
                    }
                }
                # Since PDT-C (January 2021), there is also a special class of comments that encode the standard
                # lemma when the actual lemma reflects a typo: rozpočed_,i_^(^DS**rozpočet)
                # http://ufal.mff.cuni.cz/pdt-c/publications/TR_PDT_C_morph_manual.pdf, Section 4.2.3, page 14
                elsif($comment =~ m/^\(\^DS\*\*(.*)\)$/)
                {
                    $lcorrect = $1;
                }
                else # normal comment in plain Czech
                {
                    $lgloss = $comment;
                }
            }
            # Sanity check. What if a lemma contains tags that are ill-formed?
            if($ltags ne '')
            {
                log_warn("Lemma '$lemma' contains information that cannot be understood: '$ltags'.");
            }
            # We can only process `references and -ids of the lemma proper after
            # we have processed the comments because if the comments contain a
            # derivation rule, the rule operates on the lemma with both these
            # suffixes.
            my $lid = '';
            my $lreference = '';
            # Numeric value after lemmas of numeral words.
            # Example: třikrát`3
            # Similarly some other lemmas also refer to other lemmas.
            # Example: m`metr-1
            # In general, the '`' character occurring at a non-first position signals a reference to another lemma.
            # See "Reference" at https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/m-layer/html/ch02s01.html
            # The rules that specify which version of the lemma is primary are odd.
            # For example, there is a lemma "GJ`gigajoul" and it is used both with
            # the form "GJ" and with the full words "gigajoul", "gigajoulů" etc.
            # It would be odd to remove "gigajoul" and keep "GJ" when the form is
            # "gigajoul". The following appears in PDT (forms in brackets):
            # cm`centimetr (cm)
            # g`gram (g)
            # GJ`gigajoul (gigajoul, gigajoulu, GJ)
            # GWh`gigawatthodina (GWh)
            # ha`hektar (hektar, hektaru, hektarů, hektarech, ha)
            # hl`hektolitr (hektolitrů, hl)
            # Hz`hertz (Hz)
            # J`joul (J)
            # kg`kilogram (kg)
            # kHz`kilohertz (kHz)
            # k`kůň (k)
            # km`kilometr (km)
            # kV`kilovolt (kilovoltů, kV)
            # kWh`kilowatthodina (kilowatthodin, kWh)
            # kW`kilowatt (kilowattů, kW)
            # l`litr (litr, litru, litrů, litrech, l, L)
            # MHz`megahertz (megahertzů, MHz)
            # m`metr (m)
            # mm`milimetr (mm)
            # MWh`megawatthodina (megawatthodin)
            # MW`megawatt (MW)
            # ns`nanosekunda (nanosekund, ns)
            # protistrana`strana (protistrana, protistrany) ###!!!???
            # ps`pikosekunda (PS)
            # SF`Sinn-1 (Sinn) ###!!!
            # SF`Fein-1 (Fein) ###!!!
            # s`sekunda (sec, s)
            # TJ`terajoul (terajoulů, TJ)
            # t`tuna (t, T)
            # TWh`terawatthodina (TWh)
            # V`volt (voltů, V)
            # W`watt (watty, W)
            # ...
            # šest`6
            if($lprop =~ m/^SF\`(Sinn-1|Fein-1)$/) # `
            {
                $lprop = $1;
            }
            elsif($lprop =~ s/(.)\`(.+)/$1/) # `
            {
                my $l1 = $lprop; # either abbreviation for measure units, or full word for numerals
                my $l2 = $2; # either full word for measure units, or numeric value for numerals
                my $form = $node->form();
                # Numeric value of a numeral.
                # Note that it is not enough that it contains a digit, as non-numeric lemmas may have numeric identifiers ("mm-1", "s-2").
                if($l2 =~ m/^\d+$/)
                {
                    $lreference = $l2;
                }
                # If the form is abbreviated, use the abbreviated lemma.
                elsif($l1 =~ m/^$form(-\d+)?$/i || $l1 eq 's-2' && lc($form) eq 'sec')
                {
                    $lreference = $l2;
                }
                # Otherwise use the full lemma.
                else
                {
                    $lprop = $l2;
                    $lreference = $l1;
                }
            }
            # An optional numeric suffix helps distinguish homonyms.
            # Example: jen-1 (particle) vs. jen-2 (noun, Japanese currency)
            # There must be at least one character before the suffix. Otherwise we would be eating tokens that are negative numbers.
            if($lprop =~ s/(.)-(\d+)/$1/)
            {
                $lid = "$lprop-$2";
            }
            # Save the annotation extracted from the lemma as MISC attributes, in the following order.
            $node->set_misc_attr('LId', $lid) if($lid ne '');
            $node->set_misc_attr('LNumValue', $lreference) if($lreference ne '');
            $node->set_misc_attr('LGloss', $lgloss) if($lgloss ne '');
            $node->set_misc_attr('LDeriv', $lderiv) if($lderiv ne '');
            $node->set_misc_attr('CorrectLemma', $lcorrect) if($lcorrect ne '');
            # And there is one clear bug: lemma "serioznóst" instead of "serióznost".
            $lprop =~ s/^serioznóst$/serióznost/;
            $lemma = $lprop;
            $node->set_lemma($lemma);
        }
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        if ( $deprel =~ s/_M$// )
        {
            $node->set_is_member(1);
        }
        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $deprel =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $deprel = 'Atr';
        }
        # Annotation error (one occurrence in PDT 3.0): Coord must not be leaf.
        if($deprel eq 'Coord' && $node->is_leaf() && $node->parent()->is_root())
        {
            $deprel = 'ExD';
        }
        $node->set_deprel($deprel);
    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real deprel. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->pdt_to_treex_is_member_conversion($root);
}



1;

=over

=item Treex::Block::HamleDT::CS::Harmonize

Converts Czech analytical trees from the PDT style to the style of
HamleDT (Prague). The two annotation styles are very similar, thus only
minor changes take place. Morphological tags are decoded into Interset.

This block is specific for Czech (while some Prague-style treebanks work with
other languages) but it is the common ancestor of harmonization blocks for all
PDT-style Czech treebanks. They need specific steps of their own.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2014, 2015, 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
