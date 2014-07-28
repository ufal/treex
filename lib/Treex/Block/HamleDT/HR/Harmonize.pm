package Treex::Block::HamleDT::HR::Harmonize;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'hr::multext',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Croatian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->mark_deficient_clausal_coordination($root);
    $self->fix_compound_prepositions($root);
    $self->fix_compound_conjunctions($root);
    $self->fix_other($root);
    $self->check_afuns($root);
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
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        # Attributes that we may have to query.
        my $plemma = $parent->lemma();
        # The syntactic tagset of SETimes.HR has been apparently influenced by PDT.
        # For most part it should suffice to rename the tags (or even leave them as they are).
        if($deprel eq 'Ap')
        {
            $afun = 'Apposition';
        }
        # Atv = predicate complement.
        # Rather than the verbal attribute (doplněk) of PDT, this seems to apply to infinitives attached to modal verbs.
        # However, there are other cases as well.
        elsif($deprel eq 'Atv')
        {
            my @children = $node->children();
            my $node_governs_kao = any {$_->lemma() eq 'kao'} (@children);
            $afun = 'NR';
            # Infinitive attached to modal verb.
            # Example (Croatian and Czech with PDT annotation):
            # kažu/Pred da/Sub mogu/Pred iskoristiti/Atv
            # říkají/Pred že/AuxC mohou/Obj využít/Obj
            # they-say that they-can exploit
            # The parent can also be adjective:
            # odlučni smo graditi = we are committed to build
            # The parent can also be noun:
            # imat će prigodu obratiti se sudionicima = will have the opportunity to address the participants
            if($node->is_infinitive())
            {
                $afun = 'Obj';
            }
            # Atv also occurred at a participial adjective modifying a noun:
            # 600 milijuna eura prebačenih/Atv u banke
            elsif($node->is_adjective() && $parent->is_noun())
            {
                $afun = 'Atr';
            }
            # Verbal attribute:
            # Može li Turska sama/Atv?
            elsif($node->is_adjective() && $parent->is_verb())
            {
                $afun = 'AtvV';
            }
            # Prepositional phrase loosely attached to a participial adjective.
            # proces bio prenagljen bez/Prep plana/Atv za gospodarski razvoj
            elsif($node->is_noun() && $parent->is_adposition() && $parent->parent()->is_adjective())
            {
                $afun = 'Adv';
            }
            # Transgressive (adverbial participle, here tagged as adverb) attached to a verb.
            # uzdrmavši političku scenu u zemlji
            elsif($node->is_adverb())
            {
                $afun = 'Adv';
            }
            # Nominal predicate with copula.
            # Jedan od tih napora jest reforma pravosuđa. = Jednou z těchto snah je reforma soudnictví. = One of these efforts is a reform of justice.
            elsif($plemma eq 'biti')
            {
                $afun = 'Pnom';
            }
            # Prepositional phrase as nominal predicate with copula.
            # biti u stanju = be able to
            elsif($parent->is_preposition() && $parent->parent()->lemma() eq 'biti')
            {
                $afun = 'Pnom';
            }
            # Nominal predicate with copula and modal verb is attached differently from PDT!
            # mogli bismo biti svjedoci = mohli bychom být svědky = we could be witnesses
            elsif($plemma =~ m/^(moći|morati)$/i)
            {
                my $left = $node->get_left_neighbor();
                if(defined($left) && $left->lemma() eq 'biti')
                {
                    $afun = 'Pnom';
                }
                # Annotation error: "započeti" is infinitive but it is tagged as adjective.
                # Provedba tih strategija mora započeti odmah.
                # Implementation of these strategies must begin immediately.
                if($node->form() eq 'započeti' && $node->is_adjective())
                {
                    $node->set_iset('pos' => 'verb', 'verbform' => 'inf', 'gender' => '', 'number' => '', 'case' => '', 'degree' => '');
                    $afun = 'Obj';
                }
            }
            # Annotation error? I would analyze this as a standard direct object.
            # But Treex did not catch it so far because it is in coordination an the parent is conjunction.
            # planirao je udare/Atv na ekonomske interese, kao i napade/Atv na brodove i tankere
            elsif($node->form() =~ m/^(udare|napade)$/i && $plemma eq 'i')
            {
                $afun = 'Obj';
            }
            # Adverbial.
            # su praznile bankovne račune kloniranjem/Atv njihovih kartica = they emptied their bank accounts by cloning their cards
            elsif($node->get_iset('case') eq 'ins')
            {
                $afun = 'Adv';
            }
            # Verbal attribute (doplněk in PDT).
            # Vidno ožalošćen i potresen smrću Vassilakisa, obećao je kako ...
            # ocijenile ga kao "cirkus"
            elsif($node->form() =~ m/^(ožalošćen|potresen)$/ && $parent->form() eq 'i' ||
                  $node->is_adjective() ||
                  $node_governs_kao)
            {
                $afun = 'AtvV';
            }
            # Unless we know more, prepositional phrases under verbs are probably adverbial modifiers.
            # bacila u znak protesta
            elsif($parent->is_adposition())
            {
                $afun = 'Adv';
            }
            # Unless we know more, modifiers of nouns are attributes.
            elsif($parent->is_noun())
            {
                $afun = 'Atr';
            }
            # Annotation error?
            # su/Atv svirali/Pred
            elsif($node->lemma() eq 'biti' && $node->is_leaf() && $parent->is_participle())
            {
                $afun = 'AuxV';
            }
        }
        # Reflexive pronoun/particle 'se', attached to verb.
        # Negative particle 'ne', attached to verb.
        # Auxiliary verb, e.g. 'sam' in 'Nadao sam se da' (Doufal jsem, že).
        elsif($deprel eq 'Aux')
        {
            # Auxiliary verb "biti" = "to be".
            # Auxiliary verb "htjeti" = "to want to".
            if($node->lemma() =~ m/^(biti|htjeti)$/)
            {
                $afun = 'AuxV';
            }
            ###!!! We should restructure this!
            ###!!! Normally modal verbs govern infinitives. It is different when the infinitive is an auxiliary verb:
            # Manjine ne mogu biti korištene za opravdanje vojne intervencije.
            # Minorities can not be used to justify military intervention.
            # korištene/Pred ( biti/Aux ( mogu/Aux ( ne/Aux ) ) )
            elsif($node->lemma() =~ m/^(moći|morati)$/i)
            {
                $afun = 'AuxV';
            }
            # Reflexive pronoun "se" = "oneself".
            elsif($node->lemma() eq 'sebe')
            {
                $afun = 'AuxT';
            }
            # Negative particle "ne" = "not".
            elsif($node->lemma() eq 'ne')
            {
                $afun = 'Neg';
            }
            # Question particle "li":
            # Želite li da se zakon poštuje?
            # Do you want the law to be respected?
            # Modal particle "neka" ("let"):
            # Neka vlada nastavi tražiti pojas za spašavanje.
            # Let the government continue to seek a life vest.
            elsif($node->lemma() =~ m/^(li|neka)$/)
            {
                # HamleDT does not have a fitting dependency label. Should we create a new one, e.g. AuxQ?
                # We do not use 'AuxT' because this particle is not lexically bound to particular verbs.
                # We use 'AuxR', although in PDT it has a specific use different from this one.
                $afun = 'AuxR';
            }
            # Annotation error: quotation mark node, attached to coordination, labeled 'Aux', should be 'Punc'.
            elsif($node->form() eq '"')
            {
                $afun = 'AuxG';
            }
            elsif($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            # Annotation error: numeral modifying a noun should not be labeled 'Aux'.
            elsif($node->is_numeral())
            {
                $afun = 'Atr';
            }
            # Annotation error: determiner modifying a noun should not be labeled 'Aux'.
            # taj čin = the act
            elsif($node->is_adjective())
            {
                $afun = 'Atr';
            }
            # Annotation error? "kao" should be 'Aux', or 'Oth'?
            # The conjunction "kao" = "as" is often attached as a leaf to the noun phrase it introduces.
            # Example: izgleda kao odlična ideja = vypadá jako skvělý nápad
            elsif($node->lemma() eq 'kao' && $node->is_leaf())
            {
                $afun = 'AuxY';
            }
            # Annotation error?
            # bi/Aux im/Aux!!! omogućilo
            elsif($node->form() eq 'im')
            {
                $afun = 'Obj';
            }
            # Annotation error?
            # nekolko gospodarskih sajmova i/Aux sajmova knjiga
            elsif($node->form() eq 'i')
            {
                $afun = 'Coord';
            }
        }
        elsif($deprel eq 'Co')
        {
            $afun = 'Coord';
            $node->wild()->{coordinator} = 1;
            ###!!! We must reconstruct conjuncts, they are not marked.
        }
        elsif($deprel eq 'Elp')
        {
            $afun = 'ExD';
        }
        # Also decomposed compound preposition (001#22):
        # These will be left unchanged (i.e. labeled 'Oth') and later fixed in targeted methods.
        # s obzirom da = s ohledem na to, že
        # osim toga = kromě toho
        elsif($deprel eq 'Oth')
        {
            if($node->is_conjunction())
            {
                # Coordinating conjunction at the beginning of the sentence should be analyzed as heading deficient clausal coordination.
                # We will now only change afun to 'Coord'; the rest will be done later by $self->mark_deficient_clausal_coordination().
                if($node->ord()==1)
                {
                    $afun = 'Coord';
                }
                # There are other occurrences of leaf conjunctions that actually do not coordinate anything.
                # Example: , a koje kosovska vlada ne koristi
                else
                {
                    $afun = 'AuxY';
                }
            }
            # Intensifying or emphasizing particles, adverbs etc.
            # Example: barem/Oth na papiru = alespoň na papíře
            # Example: drugi ne dobivaju gotovo/Oth ništa = jiní nedostanou téměř nic
            # Example: i/TT/Oth etnička komponenta = i etnická složka
            elsif(($node->is_adverb() || $node->is_particle()) &&
                  ($parent->is_adposition() || $parent->is_noun()) &&
                  $parent->ord() > $node->ord())
            {
                $afun = 'AuxZ';
            }
            # Other occurrences of the particle "i" should also qualify as AuxZ.
            elsif($node->form() eq 'i' && $node->is_particle())
            {
                $afun = 'AuxZ';
            }
            # Adverbial modifier / attribute.
            # Example: desetljeće kasnije/Oth = a decade later ... should be attribute because its parent is noun.
            # vrlo često = velmi často = very often ... should be adverbial
            elsif($node->is_adverb())
            {
                if($parent->is_noun())
                {
                    $afun = 'Atr';
                }
                else
                {
                    $afun = 'Adv';
                }
            }
            # osim toga = besides that
            elsif($node->form() eq 'toga')
            {
                $afun = 'Adv';
            }
            # The conjunction "kao" = "as" is often attached as a leaf to the noun phrase it introduces.
            # Example: izgleda kao odlična ideja = vypadá jako skvělý nápad
            elsif($node->lemma() eq 'kao' && $node->is_leaf())
            {
                $afun = 'AuxY';
            }
            # bilo/Oth koja = jakákoli ("koli jaká") = any
            # bilo/Oth kakvih = jakýchkoli = any
            elsif($node->form() eq 'bilo' && $plemma =~ m/^(koji|kakav)$/i)
            {
                $afun = 'Atr';
            }
            # ne samo = nejen = not only
            elsif($node->lemma() eq 'ne')
            {
                $afun = 'Neg';
            }
            # Many prepositional phrases are also labeled 'Oth'.
            elsif($node->is_adposition())
            {
                $afun = 'AuxP';
            }
            elsif($parent->is_adposition())
            {
                my $grandparent = $parent->parent();
                if(defined($grandparent))
                {
                    if($grandparent->lemma() eq 'biti')
                    {
                        $afun = 'Pnom';
                    }
                    elsif($grandparent->get_iset('pos') =~ m/^(noun|adj|num)$/)
                    {
                        $afun = 'Atr';
                    }
                    else
                    {
                        $afun = 'Adv';
                    }
                    # The preposition is often already labeled correctly but sometimes it is also 'Oth'.
                    # We do not know whether the parent has already been processed or is yet to be processed so we will also change its conll_deprel.
                    $parent->set_conll_deprel('Prep');
                    $parent->set_afun('AuxP');
                }
            }
            # Adjective attached to noun.
            # The example I found is not typical. The "adjective" is an adjectival suffix, mis-tagged as (adjectival) pronoun.
            # UN . -- ovim izaslanikom
            elsif($node->is_adjective() && $parent->is_noun())
            {
                $afun = 'Atr';
            }
            # Prepositions in foreign person names:
            # Jaap de Hoop Scheffer
            # Scheffer ( Jaap/Ap , Hoop/Ap ( de/Oth ) )
            # Elsewhere the morphological tag does not even know that this is a foreign word. It is just unknown word:
            # Osame bin/X/Oth Ladena
            elsif($node->is_foreign() || $node->get_iset('pos') eq '')
            {
                $afun = 'Atr';
            }
            # Set phrase loosely attached to a verb:
            # "Sve u svemu, pregovori s Hrvatskom dobro napreduju", ...
            # sve u svemu = all in all
            # "sve" is adjective and is attached to the verb "napreduju".
            elsif($node->is_adjective() && $parent->is_verb())
            {
                $afun = 'Adv';
            }
            # Particles:
            # što/Oth više poena = co nejvíce bodů = as many points as possible
            elsif($node->is_particle() && $node->is_leaf())
            {
                $afun = 'AuxZ';
            }
            # Determiner modifying modal particle; in fact, these two form a multi-word expression:
            # kakve/Oth god = whatever
            elsif($node->lemma() eq 'kakav' && $plemma eq 'god')
            {
                $afun = 'Atr';
            }
            # Annotation error: punctuation labeled 'Oth'.
            elsif($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            # Remaining numerals are probably attributes.
            elsif($node->is_numeral() || $node->form() eq '%')
            {
                $afun = 'Atr';
            }
            # Modifiers of nouns are probably attributes.
            elsif($parent->is_noun())
            {
                $afun = 'Atr';
            }
            # Adjectives are probably attributes even if modifying non-nouns (adjectives).
            # tim/Oth samim/Oth
            # što/N/Oth drugo/A
            elsif($node->is_adjective() || $parent->is_adjective())
            {
                $afun = 'Atr';
            }
            # Modifiers of adverbs are probably adverbials.
            # nešto/Pi/Oth kasnije = něco později = somewhat later
            elsif($parent->is_adverb())
            {
                $afun = 'Adv';
            }
            # Compound conjunctions:
            # bilo da = whether
            elsif($node->form() =~ m/^bilo$/i && $parent->form() eq 'da')
            {
                $afun = 'AuxY';
            }
            # Annotation error?
            # su/Atv svirali/Pred
            elsif($node->lemma() eq 'biti' && $node->is_leaf() && $parent->is_participle())
            {
                $afun = 'AuxV';
            }
        }
        # Preposition.
        elsif($deprel eq 'Prep')
        {
            $afun = 'AuxP';
        }
        # Punctuation: the 'Punc' label will be split to 'AuxG' and 'AuxX' (and later possibly also 'AuxK').
        elsif($deprel eq 'Punc')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        # Subordinating conjunction.
        elsif($deprel eq 'Sub')
        {
            $afun = 'AuxC';
        }
        # Set the (possibly changed) afun back to the node.
        $node->set_afun($afun);
    }
    # Fix known annotation errors. They include coordination, i.e. the tree may now not be valid.
    # We should fix it now, before the superordinate class will perform other tree operations.
    $self->fix_annotation_errors($root);
}

#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from deprel_to_afun() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # u suprotnom = otherwise
        if($node->form() eq 'suprotnom' && $parent->lemma() eq 'u' &&
           $node->afun() eq 'Oth' && $parent->afun() eq 'Adv')
        {
            $node->set_afun('Adv');
            $parent->set_afun('AuxP');
        }
        # ne postoji ništa/Sb nekompatibilno/Atv = there is nothing incompatible
        # "nekompatibilno" should not be attached directly to the verb. It should be attribute of "ništa".
        elsif($node->form() eq 'nekompatibilno')
        {
            my $ln = $node->get_left_neighbor();
            if(defined($ln) && $ln->form() eq 'ništa' && $parent->form() eq 'postoji')
            {
                $node->set_parent($ln);
                $node->set_afun('Atr');
            }
        }
        # više od 10.000 takvih strojeva = more than 10,000 such machines
        # Original annotation: a left-branching chain, including the preposition "od"!
        elsif($node->form() =~ m/^(više|manje)$/i && $parent->form() eq 'od' && $parent->parent()->is_numeral())
        {
            my $vise = $node;
            my $od = $parent;
            my $number = $parent->parent();
            if(defined($number))
            {
                my $ggp = $number->parent();
                if(defined($ggp))
                {
                    $vise->set_parent($ggp);
                    $vise->set_afun($number->afun());
                    $od->set_parent($vise);
                    $od->set_afun('AuxP');
                    $number->set_parent($od);
                    $number->set_afun('Atr');
                }
            }
        }
        # In this case, the verb "biti" is mistagged as present indicative, instead of infinitive; due to that, the afun was not translated correctly.
        # moraju biti poslani
        # must be sent
        elsif($node->form() eq 'biti' && !$parent->is_root() && $parent->form() eq 'moraju' && $node->get_iset('mood') eq 'ind')
        {
            $node->set_iset('verbform' => 'inf', 'mood' => '', 'tense' => '', 'number' => '', 'person' => '');
            $node->set_afun('Obj');
        }
        # train/002#358
        # error? should "blago" be noun instead of adjective? I would say so.
        # antičko trakijsko blago otkriveno u Bugarskoj
        elsif($node->is_adjective() && $parent->is_adjective() && $node->conll_deprel() eq 'Atv')
        {
            $node->set_afun('Atr');
        }
        # train/004#397
        # "Ali to neće biti samo pitanje političk volje.
        # "Ali" is conjunction and should govern deficient clausal coordination.
        # It is mistagged as noun. Even if it had the correct tag, subsequent processing would stumble on the quotation mark.
        elsif($node->form() eq 'Ali' && $node->ord()==2 && $node->is_noun())
        {
            my $verb = $parent;
            my $left = $node->get_left_neighbor();
            $node->set_iset('pos' => 'conj', 'conjtype' => 'coor', 'gender' => '', 'number' => '', 'case' => '');
            $node->set_afun('Coord');
            $node->set_parent($root);
            if($left)
            {
                $left->set_parent($node);
            }
            $verb->set_parent($node);
            $verb->set_is_member(1);
        }
        # test/001#230
        # Stranke stalno dolaze pune obećanja/Atv, a uvijek nas ostavljaju u siromaštvu."
        # Parties are constantly coming up full of promise, and always leave us in poverty."
        elsif($node->form() eq 'pune' && $parent->form() eq 'obećanja' && $parent->ord() == $node->ord() + 1)
        {
            my $grandparent = $parent->parent();
            $node->set_parent($grandparent);
            $node->set_afun('AtvV');
            $parent->set_parent($node);
            $parent->set_afun('Atr');
        }
        # train/006#247
        # Analitičari upozoravaju na kosovski trend: osnivanje novih političkih stranaka neposredno prije izbora, a od strane ljudi iz već postojećih političkih stranaka ili nekog drugog aspekta javnog života.
        elsif($node->afun() eq 'Oth-CYCLE:15')
        {
            my $stranaka = $nodes[9];
            my $neposredno = $nodes[10];
            my $prije = $nodes[11];
            my $a = $nodes[14]; # or $node
            my $od = $nodes[15];
            $a->set_parent($stranaka);
            $a->set_afun('Coord');
            $prije->set_parent($a);
            $prije->set_is_member(1);
            $od->set_is_member(1);
            $prije->set_afun('AuxP');
            $neposredno->set_afun('AuxZ');
        }
        # train/006#381
        # "Ne možemo mnogo učiniti kako bismo je spriječili da ide malo šetati ili plivati.
        elsif($node->afun() eq 'Adv-CYCLE:4')
        {
            my $mnogo = $nodes[3]; # or $node
            my $uciniti = $nodes[4];
            $mnogo->set_parent($uciniti);
            $mnogo->set_afun('Adv');
        }
        # test/001#25
        # Rezultat je toga da je artikulacija praktičnih zajedničkih interesa postala teža, kao i definiranje konkretnih misija.
        elsif($node->afun() eq 'Atr-CYCLE:1-CYCLE:10-CYCLE:4-CYCLE:3')
        {
            my $rezultat = $nodes[0];
            my $je = $nodes[1];
            my $toga = $nodes[2];
            my $da = $nodes[3];
            $rezultat->set_parent($je);
            $toga->set_parent($rezultat);
            $toga->set_afun('Atr');
            $da->set_parent($je);
        }
        # Unattached punctuation ($afun =~ m/^Punc-CYCLE:/).
        # train/006#399: U međuvremenu, troškovi života porasli... the comma should be attached to the highest node on the left, i.e. "U". Or, because "U" is preposition, to "međuvremenu".
        # train/007#6: "Nije riječ... the quotation mark should be attached to the main predicate ("nije").
        # train/007#250: "Teror, strah i mržnja ne smiju... the quotation mark should be attached to the main predicate, here coordinate ("a").
        # train/007#359: ... priopćila je u srijedu vlada, izražavajući... the comma should be attached to the right to "izražavajući"
        elsif($node->form() eq ',' && $node->afun() eq 'Punc-CYCLE:19')
        {
            $node->set_parent($nodes[19]);
            $node->set_afun('AuxX');
        }
        elsif($node->form() eq ',' && $node->afun() eq 'Punc-CYCLE:3')
        {
            $node->set_parent($nodes[1]);
            $node->set_afun('AuxX');
        }
        elsif($node->form() eq '"' && $node->afun() eq 'Punc-CYCLE:1')
        {
            my @children_of_root = $root->children();
            my ($predicate) = grep {$_->afun() =~ m/^(Pred|Coord)$/} (@children_of_root);
            $node->set_parent($predicate);
            $node->set_afun('AuxG');
        }
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels compound prepositions, e.g. "s obzirom" ("with the
# perspective that"), "osim toga" ("besides that").
#------------------------------------------------------------------------------
sub fix_compound_prepositions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->is_preposition() && $node->is_leaf())
        {
            my $parent = $node->parent();
            if($parent->is_noun() || $parent->is_adjective())
            {
                my $grandparent = $parent->parent();
                if(!$grandparent->is_root())
                {
                    my $ggparent = $grandparent->parent();
                    $node->set_parent($ggparent);
                    $node->set_afun('AuxP');
                    $parent->set_parent($node);
                    if($ggparent->is_noun())
                    {
                        $parent->set_afun('Atr');
                    }
                    else
                    {
                        $parent->set_afun('Adv');
                    }
                    $grandparent->set_parent($parent);
                }
            }
            # Unfortunately the analyses are not consistent.
            # I saw "da ( obzirom ( s ) )" (the version handled above)
            # but I also saw "da ( s , obzirom )".
            else
            {
                my $rn = $node->get_right_neighbor();
                if(defined($rn) && $rn->form() eq 'obzirom' && $rn->afun() eq 'Oth' && scalar($rn->children())==0)
                {
                    my $grandparent = $parent->parent();
                    if(defined($grandparent))
                    {
                        $node->set_parent($grandparent);
                        $node->set_afun('AuxP');
                        $rn->set_parent($node);
                        if($grandparent->is_noun())
                        {
                            $rn->set_afun('Atr');
                        }
                        else
                        {
                            $rn->set_afun('Adv');
                        }
                        $parent->set_parent($rn);
                    }
                }
                # "nakon što" ("after") is not exactly a compound preposition but it can be also fixed here.
                # Note that we have verified that the current node is a preposition attached as a leaf, labeled 'Oth'.
                # We should also require that its parent lies to the right because we are going to make the parent a child of the preposition.
                elsif($parent->ord() > $node->ord())
                {
                    my $grandparent = $parent->parent();
                    if(defined($grandparent))
                    {
                        $node->set_parent($grandparent);
                        $node->set_afun('AuxP');
                        $parent->set_parent($node);
                    }
                }
            }
        }
        # u vezi s = ve vztahu k = in relation to
        elsif($node->form() eq 'vezi' && $node->afun() eq 'Oth')
        {
            my $parent = $node->parent();
            my $grandparent = $parent->parent();
            if(defined($grandparent) && !$grandparent->is_root() && $parent->lemma() eq 'u' && $grandparent->lemma() eq 's')
            {
                my $ggp = $grandparent->parent();
                my $u = $parent;
                my $vezi = $node;
                my $s = $grandparent;
                my $noun = $u->get_right_neighbor();
                my $afun_to_ggp;
                if(defined($noun))
                {
                    $afun_to_ggp = $noun->afun();
                    # The noun should be labeled 'Atr' because "vezi" is noun.
                    $noun->set_afun('Atr');
                }
                else
                {
                    $afun_to_ggp = $ggp->is_noun() ? 'Atr' : 'Adv';
                }
                $u->set_parent($ggp);
                $u->set_afun('AuxP');
                $vezi->set_afun($afun_to_ggp);
                $s->set_parent($vezi);
                $s->set_afun('AuxP');
            }
        }
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels compound conjunctions, e.g. "bilo-ili" ("either-
# or").
#------------------------------------------------------------------------------
sub fix_compound_conjunctions
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->form() eq 'bilo' && $node->afun() eq 'Oth' && scalar($node->children())==0)
        {
            my $parent = $node->parent();
            if(!$parent->is_root())
            {
                my $grandparent = $parent->parent();
                if($grandparent->form() eq 'ili')
                {
                    $node->set_parent($grandparent);
                    $node->set_afun('AuxY');
                }
            }
        }
        # kao i = jako i = as also
        # kao should be labeled AuxY and as such it should not have children.
        # i should be labeled AuxZ and instead of kao, it should be attached to kao's parent.
        elsif($node->form() eq 'i' && $node->afun() eq 'AuxZ' && $node->parent()->form() eq 'kao')
        {
            my $parent = $node->parent();
            my $grandparent = $parent->parent();
            $node->set_parent($grandparent);
        }
    }
}

#------------------------------------------------------------------------------
# Restructures and relabels various other phenomena.
#------------------------------------------------------------------------------
sub fix_other
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my $grandparent = $parent->parent();
        next unless(defined($grandparent));
        # gotovo 17000 = téměř 17000
        if($node->is_numeral() && $node->afun() eq 'Oth' && $parent->form() =~ m/^gotovo$/i)
        {
            $node->set_parent($grandparent);
            $node->set_afun('Atr');
            $parent->set_parent($node);
            $parent->set_afun('Atr');
        }
        # na koji način = na každý pád = in any case
        elsif($node->form() eq 'način' && $parent->form() eq 'koji')
        {
            $node->set_parent($grandparent);
            $parent->set_parent($node);
            $parent->set_afun('Atr');
        }
        # mogli bismo biti svjedoci = mohli bychom být svědky = we could be witnesses
        # Nominal predicate with copula and modal verb is attached differently from PDT!
        elsif($node->afun() eq 'Pnom' && $parent->lemma() eq 'moći' && defined($node->get_left_neighbor()) && $node->get_left_neighbor()->lemma() eq 'biti')
        {
            my $biti = $node->get_left_neighbor();
            $node->set_parent($biti);
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HR::Harmonize

Converts SETimes.HR (Croatian) trees from their original annotation style
to the style of HamleDT (Prague).

The structure of the trees is apparently inspired by the PDT guidelines and
it should not require much effort to adjust it. Some syntactic tags (dependency
relation labels, analytical functions) have different names or have been
merged. This block will rename them back.

Morphological tags will be decoded into Interset and also converted to the
15-character positional tags of PDT.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
