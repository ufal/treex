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



#------------------------------------------------------------------------------
# Reads the Czech tree and transforms it to adhere to the HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->remove_features_from_lemmas($root);
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
        # Move the foreign feature from the lemma to the Interset features.
        if($lemma =~ s/_,t//)
        {
            $iset->set('foreign', 'foreign');
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
        elsif($node->is_noun() && !$node->is_pronoun())
        {
            $iset->set('nountype', 'com');
        }
        # Numeric value after lemmas of numeral words.
        # Example: třikrát`3
        my $wild = $node->wild();
        if($lemma =~ s/\`(\d+)//)
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
                    my $lderiv = $lemma;
                    $lderiv =~ s/.{$nrm}$//;
                    # Append the original suffix.
                    $lderiv .= $add if(defined($add));
                    if($lderiv eq $lemma)
                    {
                        log_warn("Lemma $lemma, derivation comment $comment, no change");
                    }
                    else
                    {
                        $wild->{lderiv} = $lderiv;
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
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        my $lemma = $node->lemma() // '';
        my $deprel = $node->deprel() // '';
        my $spanstring = $self->get_node_spanstring($node);
        # Two occurrences of "se" in CAC 2.0 have AuxT instead of AuxP.
        if($deprel eq 'AuxT' && $node->is_adposition())
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
        # Missing measure units are substituted by '?', which seems unfortunate because the question mark is a common punctuation symbol. Let's replace it by something more specific.
        elsif($lemma eq '?' && $deprel !~ m/^Aux[GK]$/)
        {
            # In 6 cases the wildcard represents a reflexive pronoun attached to an inherently reflexive verb.
            if($deprel eq 'AuxT')
            {
                $node->set_form('se');
                $node->set_lemma('se');
                $node->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex', 'case' => 'acc'});
            }
            else
            {
                my $symbol = '*';
                $node->set_form($symbol);
                $node->set_lemma($symbol);
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
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::Harmonize

Converts PDT (Prague Dependency Treebank) analytical trees to the style of
HamleDT (Prague). The two annotation styles are very similar, thus only
minor changes take place. Morphological tags are decoded into Interset.

=back

=cut

# Copyright 2011, 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
