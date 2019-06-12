package Treex::Block::HamleDT::CS::HarmonizeFicTree;
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
    $self->detect_proper_nouns($root);
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
###!!! DUPLICATE, SAME METHOD IS IN CS::HARMONIZE.PM! THEY SHOULD BE INHERITED FROM ONE PLACE!
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
            if($lemma =~ m/^((ně|lec|ledas?|kde|bůhví|kdoví|nevím|málo|sotva)?(kdo|cos?)(si|koliv?)?|nikdo|nic)$/)
            {
                $node->iset()->set('pos', 'noun');
            }
            elsif($lemma =~ m/(^(jaký|který)|(jaký|který)$|^(každý|všechen|sám|žádný)$)/)
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
# The tagset does not distinguish proper nouns. Mark nouns as proper if their
# lemma is capitalized.
#------------------------------------------------------------------------------
sub detect_proper_nouns
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $iset = $node->iset();
        my $lemma = $node->lemma();
        if($iset->is_noun() && !$iset->is_pronoun())
        {
            if($lemma =~ m/^\p{Lu}/)
            {
                $iset->set('nountype', 'prop');
            }
            elsif($iset->nountype() eq '')
            {
                $iset->set('nountype', 'com');
            }
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
        # The _Co suffix signals conjuncts.
        # The _Ap suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($deprel =~ s/_(Co|Ap)$//i)
        {
            $node->set_is_member(1);
            # There are nodes that have both _Ap and _Co but we have no means of representing that.
            # Remove the other suffix if present.
            $deprel =~ s/_(Co|Ap)$//i;
        }
        # Convert the _Pa suffix to the is_parenthesis_root flag.
        if($deprel =~ s/_Pa$//i)
        {
            $node->set_is_parenthesis_root(1);
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

=item Treex::Block::HamleDT::CS::HarmonizeFicTree

Converts FicTree, the Czech Fiction Treebank, to the style of HamleDT (Prague).
There are slight differences to how Prague Dependency Treebank is converted.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
