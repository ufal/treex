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
    default       => 'cs::pdt',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

has change_bundle_id => (is=>'ro', isa=>'Bool', default=>1, documentation=>'use id of a-tree roots as the bundle id');

#------------------------------------------------------------------------------
# Reads the Czech tree and transforms it to adhere to the HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);

    ###!!! Perhaps we should do this in Read::PDT.
    # The bundles in the PDT data have simple ids like this: 's1'.
    # In contrast, the root nodes of a-trees reflect the original PDT id: 'a-cmpr9406-001-p2s1' (surprisingly it does not identify the zone).
    # We want to preserve the original sentence id. And we want it to appear in bundle id because that will be used when writing CoNLL-U.
    if ($self->change_bundle_id) {
        my $sentence_id = $root->id();
        $sentence_id =~ s/^a-//;
        if(length($sentence_id)>1)
        {
            my $bundle = $zone->get_bundle();
            $bundle->set_id($sentence_id);
        }
    }
    return;
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
        my $lemma = $node->lemma();
        # Fix Interset features of pronominal words.
        if($node->is_pronominal())
        {
            # Indefinite pronouns and determiners cannot be distinguished by their PDT tag (PZ*).
            if($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|málo|sotva)?(kdo|cos?)(si|koliv?)?|nikdo|nic|nihil|nothing)$/)
            {
                $node->iset()->set('pos', 'noun');
            }
            elsif($lemma =~ m/(^(jaký|který)|(jaký|který)$|^(každý|všechen|sám|žádný|some|takýs)$)/)
            {
                $node->iset()->set('pos', 'adj');
            }
            # Pronouns čí, něčí, čísi, číkoli, ledačí, kdečí, bůhvíčí, nevímčí, ničí should have Poss=Yes.
            elsif($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|ni)?čí|čí(si|koliv?))$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('poss', 'poss');
            }
            # Pronoun (determiner) "sám" is difficult to classify in the traditional Czech system but in UD v2 we now have the prontype=emph, which is quite suitable.
            if($lemma eq 'sám')
            {
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
        my $iset = $node->iset();
        # Verb lemmas encode aspect.
        # Aspect is a lexical feature in Czech but it can still be encoded in Interset and not in the lemma.
        if($lemma =~ s/_:T_:W// || $lemma =~ s/_:W_:T//)
        {
            # Do nothing. The verb can have any of the two aspects so it does not make sense to say anything about it.
            # (But there are also many verbs that do not have any information about their aspect, probably due to incomplete lexicon.)
        }
        elsif($lemma =~ s/_:T//)
        {
            $iset->set('aspect', 'imp');
        }
        elsif($lemma =~ s/_:W//)
        {
            $iset->set('aspect', 'perf');
        }
        # Move the abbreviation feature from the lemma to the Interset features.
        # It is probably not necessary because the same information is also encoded in the morphological tag.
        if($lemma =~ s/_:B//)
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
        if($lemma =~ s/_,t//)
        {
            $iset->set('foreign', 'foreign');
        }
        # Vernacular (dialect)
        if($lemma =~ s/_,n//)
        {
            # Examples: súdit, husličky
            $iset->set('style', 'vrnc');
        }
        # The style flat _,a means "archaic" but it seems to be used inconsistently in the data. Discard it.
        # The style flat _,s means "bookish" but it seems to be used inconsistently in the data. Discard it.
        $lemma =~ s/_,[as]//;
        # Colloquial
        if($lemma =~ s/_,h//)
        {
            # Examples: vejstraha, bichle
            $iset->set('style', 'coll');
        }
        # Expressive
        if($lemma =~ s/_,e//)
        {
            # Examples: miminko, hovínko
            $iset->set('style', 'expr');
        }
        # Slang, argot
        if($lemma =~ s/_,l//)
        {
            # Examples: mukl, děcák, pécéčko
            $iset->set('style', 'slng');
        }
        # Vulgar
        if($lemma =~ s/_,v//)
        {
            # Examples: parchant, bordelový
            $iset->set('style', 'vulg');
        }
        # The style flag _,x means, according to documentation, "outdated spelling or misspelling".
        # But it occurs with a number of alternative spellings and sometimes it is debatable whether they are outdated, e.g. "patriotismus" vs. "patriotizmus".
        # And there is one clear bug: lemma "serioznóst" instead of "serióznost".
        if($lemma =~ s/_,x//)
        {
            # According to documentation in http://ufal.mff.cuni.cz/techrep/tr27.pdf,
            # 2 means "variant, rarely used, bookish, or archaic".
            $iset->set('variant', '2');
            $iset->set('style', 'rare');
            $lemma =~ s/^serioznóst$/serióznost/;
        }
        # Term categories encode (among others) types of named entities.
        # There may be two categories at one lemma.
        # JVC_;K_;R (buď továrna, nebo výrobek)
        # Poldi_;Y_;K
        # Kladno_;G_;K
        my %nametypes;
        while($lemma =~ s/_;([YSEGKRm])//)
        {
            my $tag = $1;
            my $nt = $nametags{$tag};
            if(defined($nt))
            {
                $nametypes{$nt}++;
            }
        }
        # Drop the other term categories because they are used inconsistently (see above).
        $lemma =~ s/_;[HULjgcybuwpzo]//g;
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
        # Numeric value after lemmas of numeral words.
        # Example: třikrát`3
        my $wild = $node->wild();
        if($lemma =~ s/\`(\d+)//) # `
        {
            $wild->{lnumvalue} = $1;
        }
        # An optional numeric suffix helps distinguish homonyms.
        # Example: jen-1 (particle) vs. jen-2 (noun, Japanese currency)
        # There must be at least one character before the suffix. Otherwise we would be eating tokens that are negative numbers.
        if($lemma =~ s/(.)-(\d+)/$1/)
        {
            $wild->{lid} = $2;
        }
        # Lemma comments help explain the meaning of the lemma.
        # They are especially useful for homonyms, foreign words and abbreviations; but they may appear everywhere.
        # A typical comment is a synonym or other explaining text in Czech.
        # Example: jen-1_^(pouze)
        # Unfortunately there are instances where the '^' character is missing. Let's capture them as well.
        # Example: správně_(*1ý)
        while($lemma =~ s/_\^?(\(.*?\))//)
        {
            my $comment = $1;
            # There is a special class of comments that encode how this lemma was derived from another lemma.
            # Example: uváděný_^(*2t)
            if($comment =~ m/^\(\*(\d*)(.*)\)$/)
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
                    my $lderiv = $lemma;
                    if(exists($wild->{lid}))
                    {
                        $lderiv .= '-'.$wild->{lid};
                    }
                    $lderiv =~ s/.{$nrm}$//;
                    # Append the original suffix.
                    $lderiv .= $add if(defined($add));
                    # But if it includes its own lemma identification number, remove it again.
                    $lderiv =~ s/(.)-(\d+)/$1/;
                    if($lderiv eq $lemma)
                    {
                        log_warn("Lemma $lemma, derivation comment $comment, no change");
                    }
                    else
                    {
                        $node->set_misc_attr('LDeriv', $lderiv);
                    }
                }
            }
            else # normal comment in plain Czech
            {
                push(@{$wild->{lgloss}}, $comment);
            }
        }
        $node->set_lemma($lemma);
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



#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $deprel = $node->deprel() // '';
        my $spanstring = $self->get_node_spanstring($node);
        # There are three instances of broken decimal numbers in PDT.
        if($form =~ m/^\d+$/ && $i+2<=$#nodes &&
           !$node->parent()->is_root() && $node->parent()->form() eq ',' && $node->parent() == $nodes[$i+1] &&
           $node->deprel() eq 'Atr' && !$node->is_member() && scalar($node->parent()->children())==1 &&
           $nodes[$i+2]->form() =~ m/^\d+$/)
        {
            my $integer = $node;
            my $comma = $nodes[$i+1];
            my $decimal = $nodes[$i+2];
            # The three nodes will be merged into one. The decimal node will be kept and integer and comma will be removed.
            # Numbers in PDT are "normalized" to use decimal point rather than comma, even though it is a violation of the standard Czech orthography.
            my $number = $integer->form().'.'.$decimal->form();
            $decimal->set_form($number);
            $decimal->set_lemma($number);
            my @integer_children = $integer->children();
            foreach my $c (@integer_children)
            {
                $c->set_parent($decimal);
            }
            # We do not need to care about children of the comma. In the three known instances, the only child of the comma is the integer that we just removed.
            splice(@nodes, $i, 2);
            # The remove() method will also take care of ord re-normalization.
            $integer->remove();
            $comma->remove();
            last; ###!!! V těch třech větách, o kterých je řeč, stejně nevím o další chybě. Ale hlavně mi nějak nefunguje práce s polem @nodes po umazání těch dvou uzlů.
            # $i now points to the former decimal, now a merged number. No need to adjust $i; the number does not have to be considered for further error fixing.
        }
        # One occurrence of "když" in PDT 3.0 has Adv instead of AuxC.
        elsif($deprel eq 'Adv' && $node->is_subordinator() && any {$_->is_verb()} ($node->children()))
        {
            $node->set_deprel('AuxC');
        }
        # Two occurrences of "se" in CAC 2.0 have AuxT instead of AuxP.
        elsif($deprel eq 'AuxT' && $node->is_adposition())
        {
            $node->set_deprel('AuxP');
        }
        # One occurrence of "se" in CAC 2.0 has AuxP instead of AuxT.
        elsif($deprel eq 'AuxP' && $node->is_pronoun() && $node->is_reflexive() && $node->is_leaf())
        {
            $node->set_deprel('AuxT');
        }
        # In the phrase "co se týče" ("as concerns"), "co" is sometimes tagged PRON+Sb (14 occurrences in PDT), sometimes SCONJ+AuxC (7).
        # We may eventually want to select one of these approaches. However, it must not be PRON+AuxC (2 occurrences in CAC).
        elsif(lc($form) eq 'co' && $node->is_pronoun() && $deprel eq 'AuxC')
        {
            $node->iset()->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
            $self->set_pdt_tag($node);
        }
        # Czech constructions with "mít" (to have) + participle are not considered a perfect tense and "mít" is not auxiliary verb, despite the similarity to English perfect.
        # In PDT the verb "mít" is the head and the participle is analyzed either as AtvV complement (mít vyhráno, mít splněno, mít natrénováno) or as Obj (mít nasbíráno, mít spočteno).
        # It is not distinguished whether both "mít" and the participle have a shared subject, or not (mít zakázáno / AtvV, mít někde napsáno / Obj).
        # The same applies to CAC except for one annotation error where "mít" is attached to a participle as AuxV ("Měla položeno pět zásobních řadů s kašnami.")
        elsif($deprel eq 'AuxV' && $lemma eq 'mít')
        {
            my $participle = $node->parent();
            $node->set_parent($participle->parent());
            $node->set_deprel($participle->deprel());
            $participle->set_parent($node);
            $participle->set_deprel('Obj');
        }
        # CAC 2.0: především
        elsif($lemma eq 'především' && $deprel eq 'AuxG')
        {
            $node->set_deprel('AuxZ');
        }
        # CAC 2.0 contains restored non-word nodes that were omitted in the original data (Korpus věcného stylu).
        # Punctuation symbols were restored according to orthography rules.
        # Missing numbers are substituted by the '#' wildcard.
        # Missing measure units are substituted by '?', which seems unfortunate because the question mark is a common punctuation symbol.
        # Let's replace it by something more specific.
        ###!!! This rule is a bit dangerous as we cannot check whether the input
        ###!!! data is really from CAC.
        elsif($lemma eq '?' && $deprel !~ m/^(Aux[GK]|ExD)$/)
        {
            # In 6 cases the wildcard represents a reflexive pronoun attached to an inherently reflexive verb.
            if($deprel eq 'AuxT')
            {
                $node->set_form('se');
                $node->set_lemma('se');
                $node->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex', 'case' => 'acc'});
            }
            # In dozens of cases the wildcard represents a preposition.
            elsif($deprel eq 'AuxP')
            {
                # Try to estimate the preposition based on the noun it governs.
                my @children = $node->get_children({'ordered' => 1});
                if(scalar(@children) > 1)
                {
                    @children = grep {$_->ord() > $node->ord() && !$_->is_punctuation()} (@children);
                }
                my $preparg;
                if(scalar(@children) >= 1)
                {
                    $preparg = $children[0];
                }
                my $case = '';
                if(defined($preparg))
                {
                    $case = $preparg->iset()->case();
                }
                if($case eq 'nom')
                {
                    # Nominative is error, it should be accusative.
                    # Observed with "na den" ("per day").
                    $node->set_form('na');
                    $node->set_lemma('na');
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'acc');
                    $preparg->iset()->set('case', 'acc');
                }
                elsif($case ne '')
                {
                    $node->set_form('*');
                    $node->set_lemma('&cprep;');
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', $case);
                }
                else
                {
                    $node->set_form('*');
                    $node->set_lemma('&cprep;');
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                }
                $self->set_pdt_tag($node);
            }
            else
            {
                $node->set_form('*');
                $node->set_lemma('&cwildcard;');
                $node->iset()->set('pos', 'sym');
            }
        }
        # PDT 3.0: Wrong Pnom.
        elsif($spanstring =~ m/^systém převratný , ale funkční a perspektivní$/)
        {
            my @subtree = $self->get_node_subtree($node);
            foreach my $i (1, 4, 6)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^zdravá \( to je nepoškozená chorobami nebo škůdci , nenamrzlá , nezapařená , bez známek hniloby nebo plísně \)$/)
        {
            my @subtree = $self->get_node_subtree($node);
            my $zdrava = $subtree[0];
            $zdrava->set_parent($node->parent());
            $zdrava->set_is_member(undef);
            foreach my $zc ($zdrava->children()) # ( to je nepoškozená )
            {
                $zc->set_parent($node);
            }
            foreach my $i (4, 9, 11) # nepoškozená nenamrzlá nezapařená
            {
                $subtree[$i]->set_deprel('Apposition');
                $subtree[$i]->set_is_member(1);
            }
            # "bez známek" is a prepositional phrase and the annotation must be split between the two words.
            $subtree[13]->set_is_member(1);
            $subtree[14]->set_deprel('Apposition');
            # Both "to" and "je" are AuxY in similar sentences.
            $subtree[2]->set_deprel('AuxY');
        }
        # "nejsou s to"
        elsif($node->form() eq 's' && $node->deprel() eq 'Pnom')
        {
            $node->set_deprel('AuxP');
        }
        elsif($spanstring =~ m/^jiným než zdvořilostním aktem/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_deprel('Atr'); # "aktem" should not be Pnom
        }
        elsif($spanstring =~ m/^pouze respektování dané situace na trhu peněz a vypořádání se s ní$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[8]->set_is_member(1);
        }
        elsif($spanstring =~ m/^početné a hlavně všelijaké :/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_is_member(1); # At this moment the colon still heads an apposition.
        }
        elsif($spanstring =~ m/^jen trochu nervózní policisté$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^: jakékoliv investice do oprav a modernizace nájemního bytového fondu jsou a budou ztrátové$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[5]->set_is_member(undef); # first "a"
            $subtree[10]->set_deprel('Atr'); # jsou
            $subtree[12]->set_deprel('Atr'); # budou
        }
        elsif($spanstring =~ m/^zbytečné , nevhodně složité$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^nejenom příčinou a prostředkem šíření této nemoci , ale také otráveným prostředím , ve kterém vzniká$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[11]->set_is_member(1); # prostředím
        }
        elsif($spanstring =~ m/^v podoboru elektrárenství$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('AuxP');
        }
        elsif($spanstring =~ m/^Toto nanejvýš zajímavé čtení musíme dát do souladu se skutečností/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # multi-word preposition "do souladu se"
            $subtree[6]->set_parent($subtree[8]);
            $subtree[7]->set_parent($subtree[8]);
        }
        elsif($spanstring =~ m/^PMC Personal - und Management - Beratung$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY for non-punctuation, should be Atr).
            foreach my $node (@subtree)
            {
                unless($node->is_punctuation())
                {
                    $node->iset()->set('foreign' => 'yes');
                    unless($node->form() =~ m/^Beratung$/i)
                    {
                        $node->set_deprel('Atr');
                    }
                }
            }
        }
        elsif($spanstring =~ m/^Hamburg Messe und Congres , GmbH$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY).
            my $parent = $node->parent();
            my $deprel = $node->deprel();
            my $member = $node->is_member();
            $subtree[2]->set_parent($parent);
            $subtree[2]->set_deprel('Coord');
            $subtree[2]->set_is_member($member);
            $subtree[0]->set_parent($subtree[2]);
            $subtree[0]->set_deprel('Atr');
            $subtree[0]->set_is_member(undef);
            $subtree[1]->set_parent($subtree[2]);
            $subtree[1]->set_deprel($deprel);
            $subtree[1]->set_is_member(1);
            $subtree[3]->set_parent($subtree[2]);
            $subtree[3]->set_deprel($deprel);
            $subtree[3]->set_is_member(1);
            $subtree[5]->set_parent($subtree[2]);
            $subtree[5]->set_deprel('Atr');
            $subtree[5]->set_is_member(undef);
        }
        elsif($spanstring =~ m/^nejdelším On The Burial Ground/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY).
            for(my $i = 1; $i <= 3; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^NBA New Jersey Nets$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY).
            for(my $i = 0; $i <= 2; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^(JUMP OK|World News|Worldwide Update|CNN Newsroom|Business Morning|Business Day|Business Asia)$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY).
            for(my $i = 0; $i <= 0; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^(International Euromarket Award|Headline News Update|CNN Showbiz Today)$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # Original annotation uses wrong deprels (AuxY).
            for(my $i = 0; $i <= 1; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^Essay on the principle of population as it affects the future improvement of society/i)
        {
            my @subtree = $self->get_node_subtree($node);
            for(my $i = 1; $i <= 13; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^École Supérieure de Physique et Chimie , Paříž$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            for(my $i = 1; $i <= 5; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^, U \. S \. Department of energy$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # "U" is wrongly attached as AuxP (confusion with the Czech preposition).
            $subtree[1]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^\( Dynamic Integrated Climate - Economy \)$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            for(my $i = 1; $i <= 3; $i++)
            {
                $subtree[$i]->set_deprel('Atr');
            }
        }
        elsif($spanstring =~ m/^Sin - kan$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('Atr');
            $subtree[0]->set_lemma('Sin');
            $subtree[0]->iset()->set_hash({'pos' => 'noun', 'nountype' => 'prop', 'gender' => 'masc', 'animacy' => 'inan', 'number' => 'sing', 'case' => 'nom', 'polarity' => 'pos'});
            $subtree[2]->set_lemma('kan');
            $subtree[2]->set_tag('PROPN');
            $subtree[2]->iset()->set_hash({'pos' => 'noun', 'nountype' => 'prop', 'gender' => 'masc', 'animacy' => 'inan', 'number' => 'sing', 'case' => 'nom', 'polarity' => 'pos'});
        }
        elsif($spanstring =~ m/^2 : 15 min \. před Sabym \( .*? \) a 9 : 04 min \. před/)
        {
            my @subtree = $self->get_node_subtree($node);
            my $num1 = $subtree[0];
            my $num2 = $subtree[2];
            my $colon = $subtree[1];
            $colon->set_deprel('Coord');
            $colon->set_is_member(1);
            $num1->set_deprel('ExD');
            $num1->set_is_member(1);
            $num2->set_parent($colon);
            $num2->set_deprel('ExD');
            $num2->set_is_member(1);
            $num1 = $subtree[14];
            $num2 = $subtree[16];
            $colon = $subtree[15];
            $colon->set_deprel('Coord');
            $colon->set_is_member(1);
            $num1->set_deprel('ExD');
            $num1->set_is_member(1);
            $num2->set_parent($colon);
            $num2->set_deprel('ExD');
            $num2->set_is_member(1);
        }
        elsif($spanstring =~ m/^nový nástup stran , které stály/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # "stran" has the wrong deprel 'AuxP' here.
            $subtree[2]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^, " dokud všechny řady pozorování/i) #"
        {
            my @subtree = $self->get_node_subtree($node);
            # "dokud" has the wrong deprel 'Adv' here.
            $subtree[2]->set_deprel('AuxC');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::Harmonize

Converts PDT (Prague Dependency Treebank) analytical trees to the style of
HamleDT (Prague). The two annotation styles are very similar, thus only
minor changes take place. Morphological tags are decoded into Interset.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2014, 2015 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
