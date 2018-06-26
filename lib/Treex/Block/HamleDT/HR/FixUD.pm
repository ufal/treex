package Treex::Block::HamleDT::HR::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_morphology($root);
    $self->regenerate_upos($root);
    $self->fix_relations($root);
    # The conversion to phrases and back should fix various issues such as
    # left-to-right conj or flat:foreign.
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
}



#------------------------------------------------------------------------------
# Fixes known issues in lemma, tag and features.
#------------------------------------------------------------------------------
sub fix_morphology
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        # Dative vs. locative.
        # Croatian nominals have almost always identical forms of dative and locative, both in singular and plural.
        # The treebank distinguishes the two features (case=dat and case=loc) but there are annotation errors.
        # Assume that it cannot be locative if there is no preposition.
        # (Warning: There is also a valency case at prepositions. That should not be modified.)
        # (Warning 2: Determiners and adjectives may be siblings of the preposition rather than its parents!)
        # (Warning 3: If the node or its parent is attached as conj, the rules are even more complex. Give up. Same for appos and flat parent.)
        # (Warning 4: It seems to introduce more problems than it solves, also because the dependencies are not always reliable. Give up for now.)
        if(0 && $node->is_locative() && !$node->is_adposition() && $node->deprel() ne 'conj' && $node->parent()->deprel() !~ m/^(conj|appos)$/)
        {
            my @prepositions = grep {$_->is_adposition()} ($node->children());
            if(scalar(@prepositions)==0 && $node->parent()->iset()->case() =~ m/dat|loc/)
            {
                @prepositions = grep {$_->is_adposition()} ($node->parent()->children());
            }
            if(scalar(@prepositions)==0)
            {
                $iset->set('case', 'dat');
            }
        }
        # Pronominal words.
        if($node->is_pronominal())
        {
            # Reflexive pronouns lack PronType=Prs.
            # On the other hand they have Number=Sing while they are used in plural as well.
            if($lemma eq 'sebe')
            {
                $iset->add('prontype' => 'prs', 'number' => '');
            }
            # Possessive determiners.
            elsif($lemma =~ m/^(moj|tvoj)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing');
            }
            elsif($lemma =~ m/^(njegov)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing', 'possgender' => 'masc|neut');
            }
            elsif($lemma =~ m/^(njezin|njen)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'sing', 'possgender' => 'fem');
            }
            elsif($lemma =~ m/^(naš|vaš|njihov)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss', 'possnumber' => 'plur');
            }
            # Reflexive possessive determiners.
            elsif($lemma eq 'svoj')
            {
                $iset->add('pos' => 'adj', 'prontype' => 'prs', 'poss' => 'poss');
            }
            # Interrogative or relative pronouns "tko" and "što" are now tagged as indefinite.
            elsif($lemma eq 'tko')
            {
                # It is not customary to show the person of relative pronouns, but in UD_Croatian they currently have Person=3.
                $iset->add('prontype' => 'int|rel', 'person' => '');
            }
            # If "što" works like a subordinating conjunction, it should be tagged as such.
            # We cannot recognize such cases reliably (the deprel "mark" is currently used also with real pronouns).
            # But if it is in nominative and the clause already has a subject, it is suspicious.
            elsif($lemma eq 'što')
            {
                if($node->deprel() eq 'mark' && $iset->is_nominative() && any {$_->deprel() =~ m/subj/} ($node->parent()->children()))
                {
                    $iset->set_hash({'pos' => 'conj', 'conjtype' => 'sub'});
                }
                else
                {
                    # It is not customary to show the person of relative pronouns, but in UD_Croatian they currently have Person=3.
                    $iset->add('prontype' => 'int|rel', 'person' => '');
                }
            }
            # Relative determiner "koji" is now tagged PRON Ind.
            # Do not damage cases that were already disambiguated as interrogative (and not relative).
            elsif($lemma =~ m/^(kakav|koji|koliki)$/)
            {
                $iset->add('pos' => 'adj');
                unless($iset->prontype() eq 'int')
                {
                    $iset->add('prontype' => 'int|rel');
                }
            }
            # Interrogative or relative possessive determiner "čiji" ("whose").
            elsif($lemma eq 'čiji')
            {
                $iset->add('pos' => 'adj', 'prontype' => 'int|rel', 'poss' => 'poss');
            }
            # Demonstrative pronouns have adjectival morphology and should thus be DET, although "taj" is often used as real PRON.
            elsif($lemma =~ m/^(taj|ovaj|onaj|takav)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'dem');
            }
            # Indefinite pronouns "neki" (somebody), "nešto" (something) are already correctly annotated PRON PronType=Ind.
            # Indefinite "nekakav" should be DET.
            elsif($lemma =~ m/^(nekakav)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'ind');
            }
            # Total pronoun "svatko" (everybody) is currently annotated as indefinite.
            # Same for "sve" (everything). Note that "sve" could be also a form of DET "sav" (every, all), and a PART ("imamo sve češće" = "máme stále častěji").
            elsif($lemma =~ m/^(svatko|sve)$/)
            {
                $iset->add('pos' => 'noun', 'prontype' => 'tot');
            }
            # Total "svaki" (each, every) should be DET.
            elsif($lemma =~ m/^(svaki)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'tot');
            }
            # Negative pronouns "nitko" (nobody), "ništa" (nothing) are currently annotated as indefinites.
            elsif($lemma =~ m/^(nitko|ništa)$/)
            {
                $iset->add('pos' => 'noun', 'prontype' => 'neg');
            }
            # Negative "nikakav" should be DET.
            elsif($lemma =~ m/^(nikakav)$/)
            {
                $iset->add('pos' => 'adj', 'prontype' => 'neg');
            }
        }
        # Total determiner "sav" ("every, all") is originally PRON or ADJ.
        if($lemma eq 'sav' && ($node->is_adjective() || $node->is_pronominal()))
        {
            $iset->add('pos' => 'adj', 'prontype' => 'tot', 'degree' => '');
        }
        # Pronominal quantifiers "koliko, toliko, nekoliko, mnogo, više, najviše, malo, manje, najmanje, vrlo, dosta" are currently tagged as adverbs.
        # (Lemma "mnogo" covers "mnogo, više, najviše"; lemma "malo" covers "malo, manje, najmanje".)
        # Many of them can also function as adverbs, for some it is the default function.
        # Even "koliko" ("how many, how much") can act as adverb. For "toliko", the shifted adverbial meaning is "only".
        # Example ADV: "Ne možete ni zamisliti koliko su svi plakali."
        # In some Slavic treebanks the two functions are distinguished by context ADV (adverbs of degree) vs. DET (quantity of a nominal).
        # Here we will leave them as adverbs, at least for now. But we will add NumType=Card (to mark that they are quantifiers) and PronType.
        # Only "nekoliko" ("several") seems to be clearly a quantifier because in adverbial function one would use "malo".
        if($lemma =~ m/^(koliko)$/)
        {
            $iset->add('prontype' => 'int|rel', 'numtype' => 'card');
        }
        elsif($lemma =~ m/^(toliko)$/)
        {
            $iset->add('prontype' => 'dem', 'numtype' => 'card', 'degree' => '');
        }
        elsif($lemma =~ m/^(nekoliko)$/)
        {
            $iset->add('pos' => 'adj', 'prontype' => 'ind', 'numtype' => 'card', 'degree' => '');
        }
        elsif($lemma =~ m/^(mnogo|malo|vrlo|dosta)$/)
        {
            $iset->add('pos' => 'adv', 'prontype' => 'ind', 'numtype' => 'card');
        }
        # Pronominal adverbs should get PronType.
        if($node->is_adverb())
        {
            if($lemma =~ m/^(gdje|odakle|kuda|kada|kad|otkada|kako|zašto)$/)
            {
                $iset->add('prontype' => 'int|rel');
            }
            elsif($lemma =~ m/^(tu|tamo|ovdje|ondje|sada|tada|onda|tako|stoga)$/)
            {
                $iset->add('prontype' => 'dem');
            }
            elsif($lemma =~ m/^(negdje|odnekud|ponekad|nekada|nekako)$/)
            {
                $iset->add('prontype' => 'ind');
            }
            elsif($lemma =~ m/^(svuda|uvijek|svakako)$/)
            {
                $iset->add('prontype' => 'tot');
            }
            elsif($lemma =~ m/^(nigdje|ikad|nikako)$/)
            {
                $iset->add('prontype' => 'neg');
            }
        }
        # Ordinal numerals are ADJ or ADV, not NUM.
        if($node->is_ordinal())
        {
            $iset->set('pos', 'adj');
        }
        # Verbal copulas should be AUX and not VERB.
        if($node->is_verb() && $node->deprel() eq 'cop')
        {
            # The only copula verb is "biti".
            if($lemma !~ m/^(biti|bivati)$/)
            {
                log_warn("Copula verb should have lemma 'biti/bivati' but this one has '$lemma'");
            }
            $iset->set('verbtype', 'aux');
        }
        # Finite verbs must be marked as such and must have mood.
        if($node->is_verb())
        {
            if($iset->verbform() eq '')
            {
                $iset->set('verbform', 'fin');
            }
            if($iset->verbform() eq 'fin' && $iset->mood() eq '')
            {
                # Conditional auxiliaries get cnd, everything else gets ind.
                if($node->form() =~ m/^(bih|bi|bismo|biste)$/i)
                {
                    $iset->set('mood', 'cnd');
                }
                else
                {
                    $iset->set('mood', 'ind');
                }
            }
        }
        # L-participles will be marked with Voice=Act && Tense=Past (although they can also be used to form the conditional).
        # So far the past tense was marked only at the old aorist/imperfect forms.
        if($node->is_verb() && $node->is_participle())
        {
            $iset->add('voice' => 'act', 'tense' => 'past');
        }
        # Passive participles should have the voice feature.
        # And some of them lack even the verbform feature!
        if($node->is_adjective() && $node->is_participle() || $lemma =~ m/^(predviđen|zaključen)$/)
        {
            $iset->set('verbform', 'part');
            # Is there an aux:pass, expl:pass, nsubj:pass or csubj:pass child?
            my @passchildren = grep {$_->deprel() =~ m/:pass$/} ($node->children());
            if(scalar(@passchildren) >= 1)
            {
                $iset->set('voice' => 'pass');
            }
        }
        # Converbs (adverbial participles, transgressives, gerunds) should have VerbForm=Conv, not Part.
        # Fortunately we can recognize them because they are tagged ADV (while in Czech they would be VERB).
        # Example: "govoreći", lemma "govoriti" ("speak").
        if($node->is_adverb() && $node->is_participle())
        {
            # Distinguish present converbs (-ći) and past converbs (-vši).
            if($node->form() =~ m/ši$/i)
            {
                $iset->add('verbform' => 'conv', 'tense' => 'past');
            }
            else
            {
                $iset->add('verbform' => 'conv', 'tense' => 'pres');
            }
        }
        # "jedem" (I eat), lemma "jesti", is tagged NOUN and not VERB? Annotation error.
        if($node->form() eq 'jedem' && $lemma eq 'jesti' && $node->is_noun())
        {
            $iset->set_hash({'pos' => 'verb', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'number' => 'sing', 'person' => '1'});
        }
        # '%' (percent) and '$' (dollar) will be tagged SYM regardless their
        # original part of speech (probably PUNCT or NOUN). Note that we do not
        # require that the token consists solely of the symbol character.
        # Especially with '$' there are tokens like 'US$', 'CR$' etc. that
        # should be included.
        if($node->form() =~ m/[\$%]$/)
        {
            $iset->set('pos', 'sym');
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
# Fixes known issues in dependency relations.
#------------------------------------------------------------------------------
sub fix_relations
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # Possessive adjectives (e.g. "Ashdownov", "Đinđićeve") should be attached to the possessed nouns as amod, not as nmod.
        if($node->is_adjective() && $node->is_possessive() && $node->deprel() eq 'nmod')
        {
            # The is_adjective() method captures also possessive determiners (moj, tvoj, njegov, njezin).
            if($node->is_pronominal())
            {
                $node->set_deprel('det');
            }
            else
            {
                $node->set_deprel('amod');
            }
        }
        # Reflexive pronouns of inherently reflexive verbs should be attached as expl:pv, not as compound (UD guideline).
        if($node->is_reflexive() && $node->deprel() eq 'compound')
        {
            $node->set_deprel('expl:pv');
        }
        # Relative pronouns and determiners must not be attached as mark because they are not subordinating conjunctions (although they do subordinate).
        # They must show the core function they have wrt the predicate of the subordinate clause.
        # WARNING: "što" can be also used as a subordinating conjunction: "Dobro je što nam pružaju više informacija."
        # But then it should be tagged SCONJ, not PRON!
        if($node->lemma() =~ m/^(tko|što|kakav|koji)$/ && $node->deprel() eq 'mark')
        {
            if($node->is_nominative())
            {
                $node->set_deprel('nsubj');
            }
            elsif($node->parent()->is_verb() || $node->parent()->is_participle())
            {
                if($node->is_accusative())
                {
                    $node->set_deprel('obj');
                }
                # Genitive can be obl, especially with a preposition ("od čega se odnosi...")
                # But it is not guaranteed. It could be also an object.
                elsif($node->is_genitive())
                {
                    $node->set_deprel('obl');
                }
                # Dative can be obj, iobj or obl.
                elsif($node->is_dative())
                {
                    $node->set_deprel('obj');
                }
                elsif($node->is_locative())
                {
                    # There is at least one occurrence of "kojima" without preposition which should in fact be dative.
                    if(lc($node->form()) eq 'kojima' && scalar($node->children())==0)
                    {
                        $node->iset()->set('case', 'dat');
                        $node->set_deprel('obj'); ###!!! or iobj
                    }
                    else
                    {
                        $node->set_deprel('obl');
                    }
                }
                # Instrumental can be obl:agent of passives ("čime je potvrđena važeća prognoza").
                # But it is not guaranteed. It could be also an object.
                elsif($node->is_instrumental())
                {
                    $node->set_deprel('obl');
                }
            }
            elsif(any {$_->deprel() =~ m/^(cop|aux)$/} ($node->parent()->children()))
            {
                # There is at least one occurrence of "kojima" without preposition which should in fact be dative.
                if(lc($node->form()) eq 'kojima' && $node->is_locative() && scalar($node->children())==0)
                {
                    $node->iset()->set('case', 'dat');
                }
                $node->set_deprel('nmod');
            }
        }
        # timove čiji će zadatak biti nadzor cijena
        # teams whose task will be to control price
        # We have mark(nadzor, čiji). We want det(zadatak, čiji).
        if($node->lemma() =~ m/^(čiji|koliki|koji)$/ && $node->deprel() eq 'mark')
        {
            # Remove punctuation, coordinators (", ali čije ...") and prepositions ("na čijem čelu").
            my @siblings = grep {$_->deprel() !~ m/^(punct|cc|case)$/} ($node->parent()->get_children({'ordered' => 1}));
            if(scalar(@siblings) >= 3 && $siblings[0] == $node && $siblings[1]->deprel() =~ m/^(aux|cop)/ && $siblings[2]->is_noun() &&
               $node->iset()->case() eq $siblings[2]->iset()->case() ||
               scalar(@siblings) >= 2 && $siblings[0] == $node && $siblings[1]->is_noun() &&
               $node->iset()->case() eq $siblings[1]->iset()->case() ||
               # Similar to the first one but not as restrictive: čiji se pripadnici... ("se" is obj, not aux).
               scalar(@siblings) >= 3 && $siblings[0] == $node && $siblings[2]->is_noun() &&
               $node->iset()->case() eq $siblings[2]->iset()->case())
            {
                $node->set_parent($siblings[2]);
                $node->set_deprel('det');
            }
            elsif($node->parent()->is_noun() && $node->iset()->case() eq $node->parent()->iset()->case())
            {
                $node->set_deprel('det');
            }
        }
        # uz njega možete obaviti (with him you can do)
        elsif($node->lemma() eq 'on' && $node->deprel() eq 'mark')
        {
            $node->set_deprel('obl');
        }
        # Relative adverbs (gdje, kuda, kada, kako, zašto) also should not be attached as mark.
        elsif($node->is_adverb() && $node->deprel() eq 'mark')
        {
            $node->set_deprel('advmod');
        }
        # Ordinal numerals modifying a nominal should be amod, not nummod.
        if($node->is_ordinal() && $node->deprel() eq 'nummod')
        {
            $node->set_deprel('amod');
        }
        # oko 69 kilometara (about 69 kilometers)
        # "Oko" is adverb ("approximately"), attached to the numeral as "det", which is definitely wrong.
        if($node->is_adverb() && $node->parent()->is_numeral() && $node->deprel() eq 'det')
        {
            $node->set_deprel('advmod:emph');
        }
        # Deficient sentential coordination, i.e. there is a coordinating conjunction in the beginning of the sentence:
        # A postoji i etnička komponenta, s obzirom da pojedinci iz različitih zajednica mogu reći da diskriminacija -- bilo sada ili ranije -- utječe na mogućnost da izvuku korist iz privatizacije.
        # The conjunction is currently attached to the main predicate as discourse.
        # According to the guidelines it should be cc (see also https://github.com/UniversalDependencies/docs/issues/283,
        # https://github.com/UniversalDependencies/docs/issues/237 and http://universaldependencies.org/u/dep/cc.html).
        if($node->is_coordinator() && $node->parent()->deprel() eq 'root' && $node->deprel() eq 'discourse')
        {
            $node->set_deprel('cc');
        }
        # Punctuation should be attached as punct or root.
        if($node->is_punctuation() && !$node->parent()->is_root())
        {
            $node->set_deprel('punct');
        }
        # Individual annotation errors found in the data.
        my $spanstring = $self->get_node_spanstring($node);
        # whose seat is in Brussels
        if($spanstring =~ m/^, čije je sjedište u Bruxellesu$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[5]->set_parent($node->parent());
            $subtree[5]->set_deprel($node->deprel());
            $subtree[2]->set_parent($subtree[5]);
            $subtree[2]->set_deprel('cop');
            $subtree[3]->set_parent($subtree[5]);
            $subtree[3]->set_deprel('nsubj');
            $subtree[1]->set_parent($subtree[3]);
            $subtree[1]->set_deprel('det');
            $subtree[0]->set_parent($subtree[5]);
        }
        # like communities in which minority population dominates
        elsif($spanstring =~ m/^kako zajednice u kojima dominira manjinsko stanovništvo$/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_parent($node->parent());
            $subtree[1]->set_deprel($node->deprel());
            $subtree[0]->set_parent($subtree[1]);
            $subtree[0]->set_deprel('mark');
            $subtree[4]->set_parent($subtree[1]);
            $subtree[4]->set_deprel('acl');
            $subtree[3]->set_parent($subtree[4]);
            $subtree[3]->set_deprel('obl');
        }
        # including one for best new artist of the year
        elsif($spanstring =~ m/^, među kojima i onu za najboljeg izvođača/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_parent($node->parent());
            $subtree[4]->set_deprel('conj'); # originally: parataxis
            $subtree[2]->set_parent($subtree[4]);
            $subtree[2]->set_deprel('orphan');
        }
        # Remnant relations that cannot be converted even by Udapi.
        elsif($spanstring eq '" Želite li da se zakon poštuje ili ne ?')
        {
            my @subtree = $self->get_node_subtree($node);
            # ne je remnant, má být conj
            $subtree[8]->set_deprel('conj');
        }
        elsif($spanstring eq 'Iz tog razloga , mnogo je više mladih kandidata nego ranije koji se nadmeću za dužnosti .')
        {
            my @subtree = $self->get_node_subtree($node);
            # nego ranije ... než dříve, obě visí nahoře (cc, remnant), místo toho nego má viset na ranije jako mark, ranije má viset nahoře jako advcl
            $subtree[10]->set_deprel('advcl');
            $subtree[9]->set_parent($subtree[10]);
            $subtree[9]->set_deprel('mark');
        }
        elsif($spanstring eq 'Druga je bila Ruskinja Olga Peretyatko , a treća Tae-Joong Yang iz Južne Koreje .')
        {
            my @subtree = $self->get_node_subtree($node);
            # Tae-Joong nechat viset na Ruskinja, ale jako conj; treća na ní jako orphan.
            $subtree[9]->set_deprel('conj');
            $subtree[8]->set_parent($subtree[9]);
            $subtree[8]->set_deprel('orphan');
        }
        elsif($spanstring eq 'Propast komunizma donijela je Crnogorcima višestranačku demokraciju , a na koncu i neovisnost .')
        {
            my @subtree = $self->get_node_subtree($node);
            # neovisnost převěsit na donijela jako conj, koncu je orphan
            $subtree[12]->set_parent($subtree[2]);
            $subtree[12]->set_deprel('conj');
            $subtree[10]->set_parent($subtree[12]);
            $subtree[10]->set_deprel('orphan');
        }
        elsif($spanstring eq 'Danas , prosječan Crnogorac živi lošije nego prije , kaže Kostić-Mandić , 40 , profesorica prava i bivša članica parlamenta .')
        {
            my @subtree = $self->get_node_subtree($node);
            # lošije nego/cc prije/remnant má být mark a advmod/advcl
            $subtree[6]->set_parent($subtree[7]);
            $subtree[6]->set_deprel('mark');
            $subtree[7]->set_deprel('advmod');
        }
        elsif($spanstring eq 'U tebi se budi lagana zavist , ali ne zbog toga što on ima , nego jer bi i ti želio .')
        {
            my @subtree = $self->get_node_subtree($node);
            # ne je remnant. Asi má být advmod. Jinak bych to musel předělat celé. Nego je taky remnant. Asi cc.
            $subtree[8]->set_deprel('advmod');
            $subtree[15]->set_deprel('cc');
        }
        elsif($spanstring eq 'Kulturno umjetničko društvo Otrovanec za trajni doprinos u očuvanju kulturne baštine podravskog kraja i promidžbu Općine Pitomača ; Milan Šelimber za trajni doprinos u očuvanju kulturne baštine podravskog kraja i promidžbu općine Pitomača ; Mateja Fras za iskazane rezultate i aktivan rad s mladim naraštajima u vatrogastvu ; Alen Dokuš za iskazanu hrabrost i požrtvovnost te promicanje moralnih i društvenih vrijednosti ; Julijana Pečar za izniman doprinos iskazan prilikom organizacije kulturnih događaja na području općine Pitomača ; Mladen Balić za postignute rezultate u gospodarstvu i promidžbi općine Pitomača ; Srebrna plaketa Grb Općine Pitomača : Dobrovoljno vatrogasno društvo Kladare za trajni doprinos i iznimna postignuća u vatrogastvu kroz 80 godina organiziranog postojanja i rada ; Dobrovoljnom vatrogasnom društvu Otrovanec za trajni doprinos i iznimna postignuća u vatrogastvu kroz 80 godina organiziranog postojanja i rada .')
        {
            my @subtree = $self->get_node_subtree($node);
            # jsou pěkně po dvou. Vždy prvního pověsit na društvo jako conj, druhého na prvního jako orphan.
            my $previous;
            for(my $i = 0; $i<=$#subtree; $i++)
            {
                if($subtree[$i]->deprel() eq 'remnant')
                {
                    if(defined($previous))
                    {
                        $subtree[$i]->set_parent($previous);
                        $subtree[$i]->set_deprel('orphan');
                        $previous = undef;
                    }
                    else
                    {
                        $subtree[$i]->set_parent($subtree[2]);
                        $subtree[$i]->set_deprel('conj');
                        $previous = $subtree[$i];
                    }
                }
            }
        }
        elsif($spanstring eq 'No , ako i poster promatramo kao promomaterija za " međunarodnu verifikaciju " ( jer je tako i naslovljen ) , onda se pitam otkud na posteru i Selim Bešlagić i Hidajet Repovac ?')
        {
            my @subtree = $self->get_node_subtree($node);
            # remnanty jsou "posteru" (má být ccomp a viset tam, co visí) a "Selim" (má viset na posteru jako nsubj)
            $subtree[26]->set_deprel('ccomp');
            $subtree[28]->set_parent($subtree[26]);
            $subtree[28]->set_deprel('nsubj');
            $subtree[24]->set_parent($subtree[26]);
            $subtree[24]->set_deprel('advmod');
        }
        elsif($spanstring eq 'U većini slučajeva nabava nove patrone s tintom košta koliko i cijeli pisač .')
        {
            my @subtree = $self->get_node_subtree($node);
            # pisač je remnant, má být ccomp
            $subtree[12]->set_deprel('ccomp');
        }
        elsif($spanstring eq 'Prvi je referenca na legendarni roman naslova Kvaka 22 , a drugi taj što isti broj na dresu nosi Eduardo Da Silva .')
        {
            my @subtree = $self->get_node_subtree($node);
            # remnanty jsou drugi (prvi) a taj (referenca). Drugi má viset jako conj tam, co visí. Taj má viset na drugi jako nsubj.
            $subtree[11]->set_deprel('conj');
            $subtree[12]->set_parent($subtree[11]);
            $subtree[12]->set_deprel('nsubj');
        }
        ###!!! TEMPORARY HACK: THROW AWAY REMNANT BECAUSE WE CANNOT CONVERT IT.
        if($node->deprel() eq 'remnant')
        {
            #$node->set_deprel('dep:remnant');
        }
    }
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::HR::FixUD

This is a temporary block that should fix selected known problems in the Croatian UD treebank.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
