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
# Converts the tokenization of the Czech Legal Text Treebank to the standard of
# the other Prague dependency treebanks. This involves splitting tokens and
# finding lemmas, morphological tags and dependency structure for the new
# tokens. We currently call this method from the beginning of fix_morphology.
# It means that we process the layers bottom-up, and no other conversions in
# this block have been done yet. However, convert_tags() has been called from
# the superordinate class, which means we can use Interset and we must update
# it.
#------------------------------------------------------------------------------
sub fix_tokenization
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        #----------------------------------------------------------------------
        # Verb with "-li" ("if").
        if($node->form() =~ m/^(je|není|jsou|nejsou)-(li)$/i)
        {
            my $byt = $1; # may be uppercased
            my $li = $2; # may be uppercased
            # We will need two new nodes right after the current node.
            # Shift the ords of all subsequent nodes. We must take the new list
            # of descendants, not @nodes, because we may have already inserted
            # other nodes that are not in @nodes!
            my $co = $node->ord();
            foreach my $n ($root->get_descendants({'ordered' => 1}))
            {
                if($n->ord() > $co)
                {
                    $n->_set_ord($n->ord()+2);
                }
            }
            # Create a new node for the hyphen.
            my $node1 = $node->create_child();
            $node1->_set_ord($co+1);
            $node1->set_form('-');
            $node1->set_lemma('-');
            $node1->set_tag('Z:-------------');
            $node1->set_conll_pos('Z:-------------');
            $node1->iset()->set_hash({'pos' => 'punc'});
            # Create a new node for the subordinating clitic "li".
            my $node2 = $node->create_child();
            $node2->_set_ord($co+2);
            $node2->set_form($li);
            $node2->set_lemma('li');
            $node2->set_tag('TT-------------');
            $node2->set_conll_pos('TT-------------');
            $node2->iset()->set_hash({'pos' => 'part'});
            # Adjust the no-space-after flags.
            $node2->set_no_space_after($node->no_space_after());
            $node->set_no_space_after(1);
            $node1->set_no_space_after(1);
            # Adjust the morphology of the current node.
            $node->set_form($byt);
            $node->set_lemma('být');
            # je:     VB-S---3P-AA--- Mood=Ind|Number=Sing|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act
            # není:   VB-S---3P-NA--- Mood=Ind|Number=Sing|Person=3|Polarity=Neg|Tense=Pres|VerbForm=Fin|Voice=Act
            # jsou:   VB-P---3P-AA--- Mood=Ind|Number=Plur|Person=3|Polarity=Pos|Tense=Pres|VerbForm=Fin|Voice=Act
            # nejsou: VB-P---3P-NA--- Mood=Ind|Number=Plur|Person=3|Polarity=Neg|Tense=Pres|VerbForm=Fin|Voice=Act
            if($node->form() =~ m/^je$/i)
            {
                $node->set_tag('VB-S---3P-AA---');
                $node->set_conll_pos('VB-S---3P-AA---');
                $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'sing', 'person' => '3', 'polarity' => 'pos'});
            }
            elsif($node->form() =~ m/^není$/i)
            {
                $node->set_tag('VB-S---3P-NA---');
                $node->set_conll_pos('VB-S---3P-NA---');
                $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'sing', 'person' => '3', 'polarity' => 'neg'});
            }
            elsif($node->form() =~ m/^jsou$/i)
            {
                $node->set_tag('VB-P---3P-AA---');
                $node->set_conll_pos('VB-P---3P-AA---');
                $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'plur', 'person' => '3', 'polarity' => 'pos'});
            }
            else # nejsou
            {
                $node->set_tag('VB-P---3P-NA---');
                $node->set_conll_pos('VB-P---3P-NA---');
                $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'plur', 'person' => '3', 'polarity' => 'neg'});
            }
            # Adjust the tree structure.
            # We do not know whether the calling code still stores relation types in afun or conll_deprel, or deprel.
            # To be on the safe side, we will set all three.
            # There are two possible situations:
            # 1. "není-li" is AuxV, as in "není-li dále stanoveno jinak"
            # 2. "není-li" is the head of the clause (copula or existential predicate)
            if(defined($node->deprel()) && $node->deprel() eq 'AuxV' ||
               defined($node->afun()) && $node->afun() eq 'AuxV' ||
               defined($node->conll_deprel()) && $node->conll_deprel() eq 'AuxV')
            {
                $node2->set_parent($node->parent()->parent());
                $node2->set_deprel('AuxC');
                $node2->set_afun('AuxC');
                $node2->set_conll_deprel('AuxC');
                $node->parent()->set_parent($node2);
            }
            else
            {
                $node2->set_parent($node->parent());
                $node2->set_deprel('AuxC');
                $node2->set_afun('AuxC');
                $node2->set_conll_deprel('AuxC');
                $node->set_parent($node2);
            }
            $node1->set_parent($node2);
            $node1->set_deprel('AuxG');
            $node1->set_afun('AuxG');
            $node1->set_conll_deprel('AuxG');
        }
        #----------------------------------------------------------------------
        # Multi-word terms enclosed in quotation marks, with spaces inside the
        # token!
        if($node->form() =~ m/^"(.+)"$/)
        {
            my $term = $1;
            my @words = split(/\s+/, $term);
            my $nw = scalar(@words);
            # We will need $nw+1 new nodes right after the current node.
            # Shift the ords of all subsequent nodes. We must take the new list
            # of descendants, not @nodes, because we may have already inserted
            # other nodes that are not in @nodes!
            my $co = $node->ord();
            foreach my $n ($root->get_descendants({'ordered' => 1}))
            {
                if($n->ord() > $co)
                {
                    $n->_set_ord($n->ord()+$nw+1);
                }
            }
            $node->_set_ord($co+1);
            # Create new nodes for the quotation marks.
            my $nodeq0 = $node->create_child();
            $nodeq0->_set_ord($co);
            $nodeq0->set_form('„');
            $nodeq0->set_lemma('"');
            $nodeq0->set_tag('Z:-------------');
            $nodeq0->set_conll_pos('Z:-------------');
            $nodeq0->iset()->set_hash({'pos' => 'punc'});
            $nodeq0->set_no_space_after(1);
            $nodeq0->set_deprel('AuxG');
            $nodeq0->set_afun('AuxG');
            $nodeq0->set_conll_deprel('AuxG');
            my $nodeq1 = $node->create_child();
            $nodeq1->_set_ord($co+$nw+1);
            $nodeq1->set_form('“');
            $nodeq1->set_lemma('"');
            $nodeq1->set_tag('Z:-------------');
            $nodeq1->set_conll_pos('Z:-------------');
            $nodeq1->iset()->set_hash({'pos' => 'punc'});
            $nodeq1->set_no_space_after($node->no_space_after());
            $nodeq1->set_deprel('AuxG');
            $nodeq1->set_afun('AuxG');
            $nodeq1->set_conll_deprel('AuxG');
            # Create new nodes for the extra words.
            for(my $i = 1; $i <= $#words; $i++)
            {
                my $nodew = $node->create_child();
                $nodew->_set_ord($co+$i+1);
                $nodew->set_form($words[$i]);
                $nodew->set_lemma($words[$i].'_^(from_multi_word_term)');
                $nodew->set_tag('X@-------------');
                $nodew->set_conll_pos('X@-------------');
                $nodew->iset()->set_hash({});
                if($i == $#words)
                {
                    $nodew->set_no_space_after(1);
                }
                # Unfortunately, the HamleDT/PDT deprel set does not provide
                # a label suitable for technical relations between parts of
                # a multi-word expression.
                $nodew->set_deprel('Atr');
                $nodew->set_afun('Atr');
                $nodew->set_conll_deprel('Atr');
            }
            $node->set_form($words[0]);
            $node->set_lemma($words[0].'_^(from_multi_word_term)');
            $node->set_tag('X@-------------');
            $node->set_conll_pos('X@-------------');
            $node->iset()->set_hash({});
            $node->set_no_space_after($nw==1 ? 1 : undef);
        }
    }
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
    # Fix tokenization of CLTT (the method will do nothing to other treebanks).
    $self->fix_tokenization($root);
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
# Catches possible annotation inconsistencies. This method is called from
# SUPER->process_zone() after convert_tags(), fix_morphology(), and
# convert_deprels().
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
        elsif($lemma eq '?' && $deprel !~ m/^(Aux[GK])$/)
        {
            if($deprel eq 'AuxX')
            {
                $node->set_form(',');
                $node->set_lemma(',');
                $node->iset()->set_hash({'pos' => 'punc'});
                $self->set_pdt_tag($node);
                $node->set_conll_pos($node->tag());
            }
            # ExD may be legitimate with a real question mark even in PDT, so we must be careful.
            # However, certain instances in CAC have to be replaced by a wildcard.
            # There is one occurrence of "?" and ExD in PDT that is not leaf and that should not be changed to "*":
            # článek ( ? ? ? )
            # The parentheses and the first question mark are attached as ExD to "článek". The two remaining question marks
            # are attached to the first one as AuxG.
            elsif($deprel eq 'ExD')
            {
                if($node->is_member() && $node->parent()->form() =~ m/^(a|nebo|ale|až|,)$/)
                {
                    $node->set_form('*');
                    $node->set_lemma('&cwildcard;');
                    $node->iset()->set('pos', 'sym');
                }
                elsif(!$node->is_leaf())
                {
                    my @children = $node->get_children({'ordered' => 1});
                    unless(scalar(@children)==2 &&
                           $children[0]->form() eq '?' &&
                           $children[1]->form() eq '?')
                    {
                        $node->set_form('*');
                        $node->set_lemma('&cwildcard;');
                        $node->iset()->set('pos', 'sym');
                    }
                    # Otherwise do nothing. It could be a real question mark.
                }
                # Otherwise do nothing. It could be a real question mark.
            }
            # In 6 cases the wildcard represents a reflexive pronoun attached to an inherently reflexive verb;
            # in other similar cases, the reflexive pronoun forms a reflexive passive.
            elsif($deprel =~ m/^(Aux[TR])$/)
            {
                ###!!! We assume that it is always the accusative "se", although it could also be the dative "si".
                $node->set_form('se');
                $node->set_lemma('se');
                $node->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex', 'case' => 'acc'});
                $self->set_pdt_tag($node);
                $node->set_conll_pos($node->tag());
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
                    # If the preparg is coordination, we must reach for one of the conjuncts.
                    if($case eq '' && $preparg->is_coordinator())
                    {
                        my @conjuncts = grep {$_->is_member()} ($preparg->get_children({'ordered' => 1}));
                        if(scalar(@conjuncts) >= 1)
                        {
                            $preparg = $conjuncts[0];
                            $case = $preparg->iset()->case();
                        }
                    }
                    # Sometimes the preparg itself is caseless but its adjectival attribute can reveal the case.
                    if($case eq '')
                    {
                        my @prepargattrs = grep {$_->is_adjective()} ($preparg->children());
                        if(scalar(@prepargattrs) >= 1)
                        {
                            $case = $prepargattrs[0]->iset()->case();
                        }
                    }
                    if($case eq '' && $node->parent()->form() eq 'Zruči')
                    {
                        $case = 'ins';
                        $preparg->set_form('Sázavou');
                        $preparg->set_lemma('Sázava');
                        $preparg->iset()->set_hash({'pos' => 'noun', 'nountype' => 'prop', 'gender' => 'fem', 'number' => 'sing', 'case' => 'ins', 'polarity' => 'pos'});
                        $self->set_pdt_tag($preparg);
                        $preparg->set_conll_pos($preparg->tag());
                    }
                    elsif($case eq '' && $node->parent()->form() =~ m/^(Ústí|Roudnici)$/)
                    {
                        $case = 'ins';
                        $preparg->set_form('Labem');
                        $preparg->set_lemma('Labe');
                        $preparg->iset()->set('pos', 'noun');
                        $preparg->iset()->set('nountype', 'prop');
                        $preparg->iset()->set('gender', 'neut');
                        $preparg->iset()->set('number', 'sing');
                        $preparg->iset()->set('case', 'ins');
                        $preparg->iset()->set('polarity', 'pos');
                        $preparg->iset()->clear('abbr');
                        $self->set_pdt_tag($preparg);
                        $preparg->set_conll_pos($preparg->tag());
                    }
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
                    $self->set_pdt_tag($preparg);
                    $preparg->set_conll_pos($preparg->tag());
                }
                elsif($case eq 'gen' && $preparg->form() eq 'průměru')
                {
                    # This particular occurrence is an error. The noun "průměru" is in locative, not genitive.
                    $node->set_form('o');
                    $node->set_lemma('o');
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'loc');
                    $preparg->iset()->set('case', 'loc');
                    $self->set_pdt_tag($preparg);
                    $preparg->set_conll_pos($preparg->tag());
                }
                elsif($case eq 'gen' && $preparg->form() eq 'povinností')
                {
                    # na základě svých povinností: základ should be NNIS6-----A---- Animacy=Inan|Case=Loc|Gender=Masc|Number=Sing|Polarity=Pos
                    $node->set_form('základě');
                    $node->set_lemma('základ');
                    $node->iset()->set('pos', 'noun');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('animacy', 'inan');
                    $node->iset()->set('case', 'loc');
                    $node->iset()->set('gender', 'masc');
                    $node->iset()->set('number', 'sing');
                    $node->iset()->set('polarity', 'pos');
                }
                elsif($case eq 'gen')
                {
                    # Genitive occurs with a variety of prepositions.
                    # We have to look at the concrete nouns observed in concrete situations (although the same nouns could occur with the other prepositions too!)
                    if($preparg->form() =~ m/^(pokynů|objemu|podmínek)$/)
                    {
                        $node->set_form('podle');
                        $node->set_lemma('podle');
                    }
                    elsif($preparg->form() =~ m/^(elektronů)$/)
                    {
                        $node->set_form('bez');
                        $node->set_lemma('bez');
                    }
                    elsif($preparg->form() =~ m/^(střediska|indiánů|nás|nichž)$/)
                    {
                        $node->set_form('u');
                        $node->set_lemma('u');
                    }
                    ###!!! "do města" se vyskytuje, "od města" taky
                    ###!!! "severozápadně od města" ("od města" je rozvitím slova "severozápadně")
                    elsif($preparg->form() =~ m/^(laboratoře|kultury|města|sebe)$/)
                    {
                        $node->set_form('do');
                        $node->set_lemma('do');
                    }
                    elsif($preparg->form() =~ m/^(Krosna|průsmyku|Medzilaborců|Karpat)$/)
                    {
                        $node->set_form('od');
                        $node->set_lemma('od');
                    }
                    elsif($preparg->form() =~ m/^(požadavku|hlediska|pomoci|staveb|rysů|ateliéru)$/)
                    {
                        $node->set_form('z');
                        $node->set_lemma('z');
                    }
                    elsif($preparg->form() =~ m/^(cesty)$/)
                    {
                        $node->set_form('podél');
                        $node->set_lemma('podél');
                    }
                    elsif($preparg->form() =~ m/^(roku)$/)
                    {
                        $node->set_form('během');
                        $node->set_lemma('během');
                    }
                    elsif($preparg->form() =~ m/^(povinností)$/) ###!!! na základě svých povinností: základ should be NNIS6-----A---- Animacy=Inan|Case=Loc|Gender=Masc|Number=Sing|Polarity=Pos
                    {
                        $node->set_form('základě');
                        $node->set_lemma('základ');
                    }
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'gen');
                }
                elsif($case eq 'dat')
                {
                    # Dative occurs mostly with the preposition "k" ("to").
                    # Exception: "vůči sjezdu" ("towards the congress")
                    if($preparg->form() eq 'sjezdu')
                    {
                        $node->set_form('vůči');
                        $node->set_lemma('vůči');
                    }
                    elsif($preparg->form() =~ m/^(revizionismu|antikomunismu)$/)
                    {
                        $node->set_form('proti');
                        $node->set_lemma('proti');
                    }
                    else
                    {
                        $node->set_form('k');
                        $node->set_lemma('k');
                    }
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'dat');
                }
                elsif($case eq 'acc')
                {
                    # Accusative occurs most often with the prepositions "na" ("on") and "pro" ("for").
                    if($preparg->form() =~ m/^(měsíc|rok|stavbu)$/)
                    {
                        $node->set_form('na');
                        $node->set_lemma('na');
                    }
                    else
                    {
                        $node->set_form('pro');
                        $node->set_lemma('pro');
                    }
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'acc');
                }
                elsif($case eq 'loc')
                {
                    # Locative occurs most often with the prepositions "v" ("in") and "při" ("at").
                    if($preparg->form() =~ m/^(příležitostech|kursech)$/)
                    {
                        $node->set_form('při');
                        $node->set_lemma('při');
                    }
                    else
                    {
                        $node->set_form('v');
                        $node->set_lemma('v');
                    }
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'loc');
                }
                elsif($case eq 'ins')
                {
                    # Instrumental occurs mostly with the preposition "s" ("with").
                    # The most notable exceptions are "nad" ("above") and "pod" ("under"). The former often occurs in names of cities.
                    if($preparg->form() =~ m/^(Labem|Vltavou|Sázavou|Ohří|Nisou|Doubravou|Úpou|Orlicí|Svitavou|Bečvou|Odrou|Dunajem|Rýnem)$/)
                    {
                        $node->set_form('nad');
                        $node->set_lemma('nad');
                    }
                    elsif($preparg->form() =~ m/^(lety)$/)
                    {
                        $node->set_form('před');
                        $node->set_lemma('před');
                    }
                    else
                    {
                        $node->set_form('s');
                        $node->set_lemma('s');
                    }
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                    $node->iset()->set('case', 'ins');
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
                elsif($node->parent()->form() eq 's')
                {
                    # Multi-word preposition "spolu s" ("together with").
                    $node->set_form('spolu');
                    $node->set_lemma('spolu');
                    $node->iset()->set('pos', 'adv');
                    $node->iset()->clear('abbr');
                }
                else
                {
                    $node->set_form('*');
                    $node->set_lemma('&cprep;');
                    $node->iset()->set('pos', 'adp');
                    $node->iset()->set('adpostype', 'prep');
                    $node->iset()->clear('abbr');
                }
                if($node->ord() == 1)
                {
                    my $form = $node->form();
                    $form =~ s/^(.)/\u$1/;
                    $node->set_form($form);
                }
                $self->set_pdt_tag($node);
                $node->set_conll_pos($node->tag());
            }
            elsif($deprel eq 'AuxC')
            {
                my @children = grep {!$_->is_punctuation()} $node->get_children({'ordered' => 1, 'preceding_only' => 1});
                if(scalar(@children) >= 1 && $children[-1]->form() =~ m/^i$/i)
                {
                    $node->set_form('když');
                    $node->set_lemma('když');
                    $node->iset()->set('pos', 'conj');
                    $node->iset()->set('conjtype', 'sub');
                    $node->iset()->clear('abbr');
                    $self->set_pdt_tag($node);
                    $node->set_conll_pos($node->tag());
                }
                elsif($node->parent()->form() eq 'Nechám')
                {
                    $node->set_form('protože');
                    $node->set_lemma('protože');
                    $node->iset()->set('pos', 'conj');
                    $node->iset()->set('conjtype', 'sub');
                    $node->iset()->clear('abbr');
                    $self->set_pdt_tag($node);
                    $node->set_conll_pos($node->tag());
                }
                elsif($node->parent()->form() eq 'a')
                {
                    $node->set_form('Když');
                    $node->set_lemma('když');
                    $node->iset()->set('pos', 'conj');
                    $node->iset()->set('conjtype', 'sub');
                    $node->iset()->clear('abbr');
                    $self->set_pdt_tag($node);
                    $node->set_conll_pos($node->tag());
                }
                elsif($node->parent()->form() eq 'je')
                {
                    $node->set_form('li');
                    $node->set_lemma('li');
                    $node->iset()->set('pos', 'conj');
                    $node->iset()->set('conjtype', 'sub');
                    $node->iset()->clear('abbr');
                    $self->set_pdt_tag($node);
                    $node->set_conll_pos($node->tag());
                }
                else
                {
                    $node->set_form('*');
                    $node->set_lemma('&cwildcard;');
                    $node->iset()->set('pos', 'sym');
                }
            }
            elsif($deprel eq 'AuxY' && $node->parent()->form() eq 'když')
            {
                $node->set_form('i');
                $node->set_lemma('i');
                $node->iset()->set('pos', 'conj');
                $node->iset()->set('conjtype', 'coor');
                $node->iset()->clear('abbr');
                $self->set_pdt_tag($node);
                $node->set_conll_pos($node->tag());
            }
            else
            {
                # In many cases the missing word is a copula. We will not recognize it by its deprel.
                # However, we can recognize it by the presence of a Pnom child.
                my @pnoms = grep {$_->deprel() eq 'Pnom'} ($node->get_children({'ordered' => 1}));
                if(scalar(@pnoms) == 0)
                {
                    # Maybe there is coordination of pnoms.
                    my @coords = grep {$_->deprel() eq 'Coord'} ($node->get_children({'ordered' => 1}));
                    foreach my $coord (@coords)
                    {
                        my @pnoms1 = grep {$_->deprel() eq 'Pnom'} ($coord->get_children({'ordered' => 1}));
                        if(scalar(@pnoms1) > 0)
                        {
                            push(@pnoms, @pnoms1);
                        }
                    }
                }
                if(scalar(@pnoms) >= 1)
                {
                    my @subjects = grep {$_->deprel() eq 'Sb'} ($node->get_children({'ordered' => 1}));
                    if(scalar(@subjects) == 0)
                    {
                        my @ktere = grep {$_->form() eq 'které' && $_->is_nominative()} ($node->children());
                        if(scalar(@ktere) == 1)
                        {
                            push(@subjects, $ktere[0]);
                            $ktere[0]->set_deprel('Sb');
                        }
                    }
                    my @conjuncts;
                    if($node->is_member())
                    {
                        @conjuncts = grep {$_ != $node && $_->is_member()} ($node->parent()->get_children({'ordered' => 1}));
                    }
                    if(defined($node->parent()->lemma()) && $node->parent()->lemma() =~ m/^(chtít|moci|smět|mít|muset)/ && $node->deprel() eq 'Obj')
                    {
                        $node->set_form('být');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'inf', 'polarity' => 'pos'});
                        $self->set_pdt_tag($node);
                        $node->set_conll_pos($node->tag());
                    }
                    # , není-li v pracovní smlouvě sjednána doba kratší
                    # Úbytkem pracovních sil tu vinen není ani tak zmíněný nedostatek
                    elsif(defined($node->parent()->form()) && $node->parent()->form() eq 'li' ||
                          scalar(@subjects) >= 1 && $subjects[0]->form() eq 'nedostatek')
                    {
                        $node->set_form('není');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'sing', 'person' => '3', 'polarity' => 'neg'});
                        $self->set_pdt_tag($node);
                        $node->set_conll_pos($node->tag());
                    }
                    # čerpadlo bylo složeno, ..., koncová oka byla spojena
                    elsif(scalar(@subjects) >= 1 && $subjects[0]->form() eq 'oka')
                    {
                        $node->set_form('byla');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'plur', 'gender' => 'neut', 'polarity' => 'pos'});
                        $self->set_pdt_tag($node);
                        $node->set_conll_pos($node->tag());
                    }
                    elsif(scalar(@subjects) >= 1 && $subjects[0]->is_plural() ||
                          scalar(@conjuncts) >= 1 && $conjuncts[0]->is_plural() ||
                          $pnoms[0]->is_plural())
                    {
                        $node->set_form('jsou');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'plur', 'person' => '3', 'polarity' => 'pos'});
                        $self->set_pdt_tag($node);
                        $node->set_conll_pos($node->tag());
                    }
                    else
                    {
                        $node->set_form('je');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'sing', 'person' => '3', 'polarity' => 'pos'});
                        $self->set_pdt_tag($node);
                        $node->set_conll_pos($node->tag());
                    }
                }
                elsif($node->deprel() eq 'AuxV')
                {
                    if($node->parent()->form() eq 'schválen')
                    {
                        $node->set_form('byl');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'sing', 'gender' => 'masc', 'animacy' => 'anim', 'polarity' => 'pos'});
                    }
                    elsif($node->parent()->form() =~ m/^(dodán|splněn)$/)
                    {
                        $node->set_form('byl');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'sing', 'gender' => 'masc', 'animacy' => 'inan', 'polarity' => 'pos'});
                    }
                    elsif($node->parent()->form() eq 'odkryta')
                    {
                        $node->set_form('byla');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'sing', 'gender' => 'fem', 'polarity' => 'pos'});
                    }
                    elsif($node->parent()->form() eq 'pracováno')
                    {
                        $node->set_form('bylo');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'sing', 'gender' => 'neut', 'polarity' => 'pos'});
                    }
                    elsif($node->parent()->form() eq 'stavěny')
                    {
                        $node->set_form('byly');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'part', 'tense' => 'past', 'voice' => 'act', 'number' => 'plur', 'gender' => 'fem', 'polarity' => 'pos'});
                    }
                    elsif($node->parent()->form() eq 'a')
                    {
                        $node->set_form('by');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'cnd', 'number' => 'sing', 'person' => '3'});
                    }
                    elsif($node->parent()->form() eq 'zdrželi')
                    {
                        $node->set_form('bychom');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'cnd', 'number' => 'plur', 'person' => '1'});
                    }
                    elsif($node->parent()->form() =~ m/^(realizovat)$/)
                    {
                        $node->set_form('je');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'sing', 'person' => '3'});
                    }
                    elsif($node->parent()->form() =~ m/^(budovány|osazeny|zmítány)$/)
                    {
                        $node->set_form('jsou');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act', 'number' => 'plur', 'person' => '3'});
                    }
                    elsif($node->parent()->form() eq 'převádět')
                    {
                        $node->set_form('budou');
                        $node->set_lemma('být');
                        $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'fut', 'voice' => 'act', 'number' => 'plur', 'person' => '3'});
                    }
                    else
                    {
                        $node->set_form('*');
                        $node->set_lemma('&cwildcard;');
                        $node->iset()->set('pos', 'sym');
                    }
                    $self->set_pdt_tag($node);
                    $node->set_conll_pos($node->tag());
                }
                else
                {
                    $node->set_form('*');
                    $node->set_lemma('&cwildcard;');
                    $node->iset()->set('pos', 'sym');
                }
            }
        }
        # CAC 2.0: Nested coordination: forgot _Co in Coord_Co.
        elsif($spanstring =~ m/^měkká , pružná a napjatá , dobře prokrvená , svěží barvy a jemné struktury$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_is_member(1);
        }
        elsif($spanstring =~ m/^důsledně vědeckou filozofickou doktrínou , jakou je dialektický a historický materialismus , nebo eklektickým souhrnem různých pozitivistických směrů$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[14]->set_is_member(1);
        }
        # CAC 2.0: Wrong Pnom.
        elsif($spanstring =~ m/^metoda sovětského novátora .* zaměřená na boj .* v závodech našeho odvětví$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[6]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^Je všeobecně známá značka ESČ , jíž jsou označovány elektrotechnické výrobky$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[8]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^K pocitu plného , bohatého , šťastného života jsou hmotné podmínky teprve určitým východiskem , jedním z předpokladů/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[13]->set_is_member(1);
        }
        elsif($spanstring =~ m/^jen tituly a pracovní .* akcí/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_is_member(1);
        }
        elsif($spanstring =~ m/^důkladná , doprovázená hlučným smíchem a jadrnými vtipy$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^popudlivé a zlostné , lhostejné až netečné , sobecké$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_is_member(1);
        }
        elsif($spanstring =~ m/^zahradách , kde není nic vysázeno a zaseto$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_parent($subtree[0]);
            $subtree[3]->set_deprel('Atr');
            $subtree[1]->set_parent($subtree[3]);
            $subtree[2]->set_parent($subtree[3]);
            $subtree[4]->set_parent($subtree[3]);
            $subtree[6]->set_parent($subtree[3]);
        }
        elsif($spanstring =~ m/^dosažitelné jen velmi obtížně nebo i vůbec nedosažitelné$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^pohyblivost elektronů zahrnující v sobě/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^, které jsou běžné nebo aspoň dostupné každému/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_is_member(1);
            $subtree[6]->set_is_member(1);
        }
        elsif($spanstring =~ m/^, jimiž je dědičností vybaven$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^cenné nejen pro lexikální statistiku , ale i pro gramatiku , s níž je slovník slovnědruhovým aspektem rovněž těsně spjat , dále pro sémantiku a stylistiku$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[20]->parent());
            $subtree[20]->set_parent($subtree[0]);
            $subtree[6]->set_parent($subtree[20]);
            $subtree[6]->set_is_member(1);
            $subtree[21]->set_parent($subtree[24]);
            $subtree[21]->set_deprel('AuxZ');
            $subtree[21]->set_is_member(undef);
            $subtree[23]->set_deprel('Adv');
            $subtree[25]->set_deprel('Adv');
        }
        elsif($spanstring =~ m/^řehole benediktinská$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^už nikoliv pouze vlastním , čistým náboženstvím , nýbrž teologickou formou náboženství , náboženstvím uvedeným do systému s pomocí a použitím mimonáboženských , racionálních prvků a postupů , náboženstvím , které je jistým způsobem sladěno , zharmonizováno s pozitivním , relativně pravdivým poznáním skutečnosti a kulturními produkty lidské činnosti , náboženstvím racionálně filozoficky odůvodněným$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[12]->set_is_member(1);
        }
        elsif($spanstring =~ m/^souhrn výtvorů lidské činnosti , materiálních i nemateriálních , souhrn hodnot i uznávaných způsobů jednání/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[9]->set_is_member(1);
        }
        elsif($spanstring =~ m/^nástrojem sociální kontroly a prostředkem moci$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^Větnými dvojicemi jsou syntaktická spojení v určitém vztahu , predikačním , otec píše , determinačním , starý otec , apozičním , Karel , král český , a koordinačním , města a vesnice$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_parent($subtree[26]->parent());
            $subtree[1]->set_parent($subtree[2]);
            $subtree[26]->set_parent($subtree[7]);
            $subtree[9]->set_parent($subtree[26]);
            $subtree[9]->set_is_member(1);
            $subtree[14]->set_deprel('Atr');
            $subtree[19]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^nafukování , nabubřování$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^U centralizovaného zásobování je energeticky výhodnější použití tepláren dodávajících současně teplo i elektřinu než výtopen dodávajících pouze teplo$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[13]->set_deprel('AuxC');
        }
        elsif($spanstring =~ m/^umístěn v krajních případech buď přímo uvnitř oblasti zásobované teplem , nebo naopak ve velké vzdálenosti od ní$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^Potom je to uhlí zvláště hnědé$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[5]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^nerozpustné ve vodě a odolné proti chemickým látkám$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_is_member(1);
        }
        elsif($spanstring =~ m/^tak velký , oslnivě krásný a nápadný$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_is_member(1);
        }
        elsif($spanstring =~ m/^asi o .* širší a .* delší/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_is_member(1);
        }
        elsif($spanstring =~ m/^komutační špičky , zapalovací impulsy , jiskření na komutátorech trakčních a pomocných motorů , spínací pochody$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_is_member(1);
        }
        elsif($spanstring =~ m/^analogické či takřka totožné faktory působící/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^, aniž by měnil její směr$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_parent($subtree[3]);
        }
        elsif($spanstring =~ m/^, které jsou vytištěny na poukazech/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^nejpozději . měsíce před skončením lhůty$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_parent($subtree[0]);
            $subtree[1]->set_parent($subtree[2]);
            $subtree[1]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^jako další akci výstavbu$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[3]);
            $subtree[0]->set_deprel('AuxC');
            $subtree[2]->set_parent($subtree[0]);
        }
        elsif($node->form() eq 'se' && $node->deprel() =~ m/^Aux[RT]$/)
        {
            # Error: preposition instead of pronoun.
            $node->set_lemma('se');
            $node->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'yes', 'case' => 'acc', 'variant' => 'short'});
            $self->set_pdt_tag($node);
            $node->set_conll_pos($node->tag());
        }
        elsif($spanstring =~ m/^Jsou to vřelá slova , která jsou pro nás povzbuzením/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('Obj');
        }
        elsif($spanstring =~ m/^víc než dříve$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_deprel('AuxC');
        }
        elsif($spanstring =~ m/^být uspokojivě řešeno na sjezdu/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('AuxV');
        }
        elsif($node->form() eq 'prosím' && $node->deprel() eq 'AuxY')
        {
            $node->set_deprel('Adv');
        }
        elsif($spanstring =~ m/^v rámci celkové opravy$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_deprel('AuxP');
        }
        elsif($spanstring =~ m/^Bylo z ní cítit onu vášeň po ničení$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[3]->parent());
            $subtree[0]->set_deprel('Pred');
            $subtree[3]->set_parent($subtree[0]);
            $subtree[3]->set_deprel('Sb');
        }
        elsif($spanstring =~ m/^Co když právě ve vaší třídě upíná/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[6]->parent());
            $subtree[0]->set_deprel('ExD');
            $subtree[1]->set_parent($subtree[6]->parent());
            $subtree[1]->set_deprel('AuxC');
            $subtree[6]->set_parent($subtree[1]);
            $subtree[6]->set_deprel('ExD');
        }
        elsif($spanstring =~ m/^, že bude třeba ve větší míře než dosud uplatňovat jasně formulované zásady/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_parent($subtree[1]);
            $subtree[2]->set_deprel('Obj');
            $subtree[9]->set_parent($subtree[2]);
            $subtree[9]->set_deprel('Sb');
        }
        elsif($spanstring =~ m/^Budiž (řečeno|napřed konstatováno) , že/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_deprel('AuxV');
        }
        elsif($spanstring =~ m/^kolem . až . dní$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[4]);
            $subtree[0]->set_deprel('AuxP');
            $subtree[2]->set_parent($subtree[0]);
        }
        elsif($spanstring =~ m/^hodnotám kolem . v současnosti$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_parent($subtree[0]);
            $subtree[1]->set_deprel('AuxP');
            $subtree[2]->set_parent($subtree[1]);
        }
        elsif($spanstring =~ m/^pouze s tím , že provádění statistické přejímky bude dohodnuto/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_deprel('AuxC');
        }
        elsif($spanstring =~ m/^Obdobně by měla být rozdělena záruční doba/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_deprel('Obj');
        }
        elsif($spanstring =~ m/^v poměru . vztaženo/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_parent($subtree[1]);
            $subtree[2]->set_deprel('Atr');
        }
        elsif($spanstring =~ m/^do vhodného substrátu , to je do správně volené zeminy$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[3]->set_parent($subtree[5]->parent());
            $subtree[0]->set_parent($subtree[3]);
            $subtree[0]->set_is_member(1);
            $subtree[6]->set_parent($subtree[3]);
            $subtree[6]->set_is_member(1);
            $subtree[5]->set_parent($subtree[7]);
            $subtree[5]->set_deprel('Pred');
        }
        elsif($spanstring =~ m/^, z nichž jedna váží až . .$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[6]->set_deprel('Obj');
        }
        elsif($spanstring =~ m/^vážící . .$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_deprel('Obj');
        }
        elsif($spanstring =~ m/^přes milióny mladých lidí , kteří jsou dnes ve věku . let$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[1]->parent());
            $subtree[0]->set_deprel('AuxP');
            $subtree[1]->set_parent($subtree[0]);
        }
        elsif($spanstring =~ m/^kmitočtech okolo . . a . .$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_parent($subtree[0]);
            $subtree[1]->set_deprel('AuxP');
            $subtree[4]->set_parent($subtree[1]);
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
        # CLTT: Prepositions "od" and "do" are sometimes wrongly tagged as prefixes (ADJ+Hyph=Yes).
        elsif($node->form() =~ m/^(od|do)$/i && $node->deprel() eq 'AuxP' && !$node->is_adposition())
        {
            $node->set_tag('RR--2----------');
            $node->set_conll_pos('RR--2----------');
            $node->iset()->set_hash({'pos' => 'adp', 'adpostype' => 'prep', 'case' => 'gen'});
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
