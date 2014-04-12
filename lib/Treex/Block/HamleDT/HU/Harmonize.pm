package Treex::Block::HamleDT::HU::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'hu::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

# /net/data/conll/2007/hu/doc/README

sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    $self->rehang_subconj($root);
    $self->check_afuns($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# for deprels see /net/data/conll/2007/hu/doc/dep_szegedtreebank_en.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    foreach my $node (grep {not $_->is_coap_root and not $_->afun} $root->get_descendants)
    {
        my $deprel = $node->conll_deprel();
        my ($parent) = $node->get_eparents(); ###!!! This works only because we convert labels AFTER coordination. Unlike in most other treebanks.
        my $pos    = $node->get_iset('pos');
        my $subpos = $node->get_iset('subpos');
        my $ppos   = $parent ? $parent->get_iset('pos') : '';
        my $afun = 'NR';
        # Since the documentation says that the following are arguments (not adjuncts), and since they are noun phrases
        # in various cases other than nominative, I label them "Obj". Some of the instances would probably be translated
        # by expressions that would be considered adverbial modifiers ("Adv") but the borderline is fuzzy and if the verb
        # really subcategorizes for these...
        # ABL = verbal argument in ablative case (attól, évektől, 1-jétől, tőle, tőlük)
        # ADE = verbal argument in adessive case (nála, nálunk, Ennél, IBM-nél, Morininál)
        # ALL = verbal argument in allative case (ahhoz, ehhez, hozzá, amelyhez, amihez)
        # CAU = verbal argument in causalis case (azért, forintért, érettünk, dollárért, érte)
        # DAT = verbal argument in dative case (HVG-nek, neki, lapunknak, magának, nekik)
        # DEL = verbal argument in delative case (arról, róla, erről, amelyről, háborúról)
        # DIS = verbal argument in distributive case (családonként, hetenként, másodpercenként, négyzetméterenként, percenként)
        # ELA = verbal argument in elative case (ebből, amelyből, belőle, abból, szempontból)
        # ESS = verbal argument in essive case (ráadásul, legtöbben, hírül, segítségül, tudomásul)
        # FAC = verbal argument in factive case (lehetővé, bérmunkássá, felelőssé, fizetésképtelenné, gyógyíthatóvá)
        # FOR = verbal argument in essive-formal case (elsőként, hitelezőként, igazgatóként, következményeként, következőképpen)
        # GEN = verbal argument in genitive case (annak, akinek, amelynek, Magyarországnak, Pinochetnek)
        # ILL = verbal argument in illative case (figyelembe, forgalomba, helyzetbe, eszébe, felszámolásába)
        # INE = verbal argument in inessive case (években, évben, amelyben, abban, érdekében)
        # INS = verbal argument in instrumental case (azzal, százalékkal, ezzel, vele, egymással)
        # LOC = verbal argument in locative case (helyütt)
        # OBJ = object (accusative case) (azt, amit, ezt, magát, amelyet)
        # SOC = verbal argument in sociative case (kamatostul)
        # SUB = verbal argument in sublative case (arra, erre, rá, forintra, évre)
        # SUP = verbal argument in superessive case (alapján, során, elején, végén, Magyarországon)
        # TEM = verbal argument in temporalis case (órakor, elkövetésekor, induláskor, perckor, átadásakor)
        # TER = verbal argument in terminative case (végéig, addig, ideig, évig, napig)
        if($deprel =~ m/^(ABL|ADE|ALL|CAU|DAT|DEL|DIS|ELA|ESS|FAC|FOR|GEN|ILL|INE|INS|LOC|OBJ|SOC|SUB|SUP|TEM|TER)$/)
        {
            $afun = 'Obj';
        }
        # ADV = adverbial phrase (például, még, már, csak, mintegy)
        elsif($deprel eq 'ADV')
        {
            $afun = 'Adv';
        }
        # ATT = attribute (több, első, az, két, új)
        elsif($deprel eq 'ATT')
        {
            $afun = 'Atr';
        }
        # AUX = auxiliary verb (volna)
        # The only word with this label is "volna", 3rd person singular conditional present indefinite of "van" ("be, exist, have").
        # When combined with past tense indicative of a finite, content verb, "volna" creates past tense conditional.
        # (Non-past conditional has synthetic forms.)
        elsif($deprel eq 'AUX')
        {
            $afun = 'AuxV';
        }
        # CONJ = conjunction (és, hogy, is, mint, ha)
        # This label is used both for coordinating conjunctions (e.g. "és" = "and") and subordinating conjunctions (e.g. "hogy" = "that").
        elsif($deprel eq 'CONJ')
        {
            if($node->is_coordinator())
            {
                $afun = 'AuxY';
                $node->wild()->{coordinator} = 1;
            }
            else # subordinating conjunction
            {
                $afun = 'AuxC';
            }
        }
        # CP = clause phrase (volt, van, hogy, kell, lesz)
        # coordinate main clauses (In this case there is Prague-style coordination: conjunction is "ROOT", clause predicates attached to it as "CP".)
        # also attached hierarchically (no conjunction, just a comma, attached to the parent predicate):
        # Míg azonban a szocialista politikus 19 parlamenti tanácskozásra ment be négy évvel ezelőtt, Orbán Viktor az idén eddig összesen 13 alkalommal tett látogatást az ülésteremben.
        # However, while the socialist politician went into 19 parliamentary deliberations four years ago, Viktor Orbán visited so far this year only 13 times the meeting room.
        # In the above sentence, the original treebank has the "while" clause govern the "Orbán" clause.
        # subordinate clauses (attached to adverb "mint" = "than")
        # parenthetical clauses in parentheses or hyphens (attached to the main predicate)
        ###!!! This must be corrected later so that "Pred" appears only at places where it is allowed.
        elsif($deprel eq 'CP')
        {
            $afun = 'Pred'; ###!!!
        }
        # DET = determiner (article) (a, az, egy)
        elsif($deprel eq 'DET')
        {
            ###!!! In the future, we may want to change this to "AuxA" but now the "AuxA" label is unsupported.
            $afun = 'Atr';
        }
        # The following verbal arguments are expressed by adverbs instead of noun phrases in respective cases (so they are "referring", not directly describing the place/time).
        # FROM = verbal argument referring to location (from) (innen, onnan, ahonnan, közülük, messziről) (from here, from there, from where, of which, from afar)
        # GOAL = verbal argument referring to goal (csatlakozzanak, eldöntsék, elkerülendő, ellophassa, felhívják) (join, determine, avoid, steal, call)
        # LOCY = verbal argument referring to location (where) (ahol, itt, ott, hol, otthon) (where, here, there, where, home)
        # MODE = verbal argument referring to mode (csak, úgy, is, így, éppen) (only, so, also, thus, just)
        # TFROM = verbal argument referring to time (from) (azóta, éve, ideje, hete, napja) (since then, years, time, week, day)
        # TLOCY = verbal argument referring to time (when) (már, még, akkor, amikor, most) (already, still, then, when, now)
        # TO = verbal argument referring to location (to) (tovább, ide, hová, ahová, előre) (further, here, where, where, ahead)
        # TTO = verbal argument referring to time (to) (eddig, tovább, amíg, továbbra, sokáig) (so far, further, until, still, long)
        elsif($deprel =~ m/^(FROM|GOAL|LOCY|MODE|TFROM|TLOCY|TO|TTO)$/)
        {
            $afun = 'Adv';
        }
        # Infinitive as argument of another verb (tenni, tartani, elérni, tudni, fizetni)
        # partnerek készülnek megszavazni = lit. partners are-prepared to-vote
        # kívánja demonstrálni = wishes to demonstrate
        # tudni kell = need to know (lit. to-know need)
        elsif($deprel eq 'INF')
        {
            $afun = 'Obj';
        }
        # NEG = negation (nem, sem, ne, se)
        elsif($deprel eq 'NEG')
        {
            $afun = 'Neg';
        }
        # NP = noun phrase
        # It is always attached to either a verb, or a conjunction (probably coordination of noun phrases).
        # It is not clear why it is not labeled as either subject (if it is in nominative) or object.
        # Example: amelynek, annak, ennek, és, képes
        elsif($deprel eq 'NP')
        {
            if($node->get_iset('case') eq 'nom')
            {
                $afun = 'Sb';
            }
            else
            {
                $afun = 'Obj';
            }
        }
        # PP = postposition (szerint, után, között, által, alatt) (according to, after, between, by, during)
        # This label says that the node is postposition but it does not reveal its function towards its parent.
        # Unlike in PDT, the function is not labeled at the child of the postposition either.
        # The child (noun) is always labeled as attribute but the postpositional phrase is always attached to verb.
        ###!!! Later on we should relabel the child of the postposition to "Adv"!
        elsif($deprel eq 'PP')
        {
            $afun = 'AuxP';
        }
        # PRED = predicate NP (az, képes, hajlandó, több, forint)
        # This may be an adjective or noun attached to a form of a copula verb ("to be", "to become" and similar): "voltak jók" = "were good"
        # However, some occurrences are different: modality is added to the parent verb (which can hardly be described as copula):
        # képes felmutatni = can show (felmutatni is infinitive "to show"; képes is adjective "able", attached to felmutatni as PRED)
        # volt képes választani = was able to choose (volt means "was" and it is parent of both képes "able" and választani "to choose")
        elsif($deprel eq 'PRED')
        {
            ###!!! We should later reshape the constructions with "képes".
            $afun = 'Pnom';
        }
        # PREVERB = preverb (meg, el, ki, be, fel)
        # Despite being called preverb in the documentation, I always saw these elements after the verb to which they were attached.
        # They are particles that modify the meaning of the verb.
        elsif($deprel eq 'PREVERB')
        {
            $afun = 'AuxT';
        }
        # PUNCT = punctuation character (, . — " :)
        # AuxX should be used for commas, AuxG for other graphic symbols.
        elsif($deprel eq 'PUNCT')
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
        # ROOT = the only child of the root, i.e. the main predicate; in case of coordinate clauses, conjunction could be ROOT
        # Most frequent words: és, s, de, hogy, volt
        elsif($deprel eq 'ROOT')
        {
            ###!!! If this is an incomplete sentence without verb, the main node should be "ExD" instead of "Pred".
            ###!!! However, testing part of speech would not work now because of the conjunctions in case of coordinate clauses.
            if($node->is_coordinator())
            {
                $node->wild()->{coordinator} = 1;
            }
            $afun = 'Pred';
        }
        # QUE = query word
        # Only these three: -e, vajon, ugye
        # "ugye" is adverb and means "isn't it" (Wiktionary)
        # "vajon" is adverb and means "I wonder [if]" (Wiktionary)
        # "-e" is interrogative particle attached to predicates: Nem tudom, voltál-e már Budapesten. - I don't know if you've ever been in Budapest. (Wiktionary)
        elsif($deprel eq 'QUE')
        {
            ###!!! If we convert it to AuxC we should later reshape the tree so that it governs the verb (now it is attached to the verb).
            $afun = 'AuxC';
        }
        # SUBJ = subject (aki, amely, az, ez, kormány)
        elsif($deprel eq 'SUBJ')
        {
            $afun = 'Sb';
        }
        # UK = unknown
        # There are only three occurrences in the corpus.
        elsif($deprel eq 'UK')
        {
            $afun = 'ExD';
        }
        # VERB2 = secondary verb
        # A verb attached to another verb. Not an auxiliary verb! This is not a periphrastic verb construction, the two verbs do not cooperate closely.
        # This label appears in various situations (that should probably be analyzed differently).
        # 1. parenthetical imperative ("Lord have mercy on you")
        # 2. sort of argument of the above verb ("amelynek csak a 30 százalékát kellett/V készpénzben kifizetni/VERB2" = had to pay)
        # 3. badly analyzed coordination of verbs ("hogy segélyt gyűjtsenek/V és osszanak/VERB2 szét")
        elsif($deprel eq 'VERB2')
        {
            ###!!! It will be difficult to correct all 81 occurrences to something meaningful.
            ###!!! I saw the coordination case several times, so one should probably focus on that.
            ###!!! For the time being, I am using "Adv" as the default label for a child of a verb.
            $afun = 'Adv';
        }
        # XP = inserted fragment
        # 271 occurrences in the corpus.
        elsif($deprel eq 'XP')
        {
            ###!!! we may also want to set is_parenthesis_root to 1 but we should investigate the examples.
            $afun = 'ExD';
        }
        $node->set_afun($afun);
    }
    # Fix known irregularities in the data.
    # Do so here, before the superordinate class operates on the data.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors and irregularities.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        # The "not only" part of compound conjunction "not only ... but" should be written as one word, "nemcsak".
        # Cases like "nem csak" and "nem-csak" are tagged as typos. The real part of speech is thus not visible, which results in other errors.
        if($node->is_typo() || $node->is_foreign())
        {
            if($node->form() eq 'nem-csak')
            {
                $node->set_afun('AuxY');
            }
            elsif($node->form() eq 'nem' && $node->parent()->form() eq 'csak')
            {
                $node->set_afun('Neg');
                $node->parent()->set_afun('AuxY');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Hungarian
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_szeged($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return non-head conjuncts, private modifiers of the head conjunct and all shared modifiers for the Stanford family of styles.
    # (Do not return delimiters, i.e. do not return all original children of the node. One of the delimiters will become the new head and then recursion would fall into an endless loop.)
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = grep {$_ != $node} ($coordination->get_conjuncts());
    return @recurse;
}



sub rehang_subconj {
    my ( $self, $root ) = @_;
    foreach my $auxc (grep {$_->afun eq 'AuxC'} $root->get_descendants) {

        my $left_neighbor = $auxc->get_left_neighbor();
        if ($left_neighbor and $left_neighbor->form eq ',') {
            $left_neighbor->set_parent($auxc);
        }

        my $right_neighbor = $auxc->get_right_neighbor();
        if ($right_neighbor and ($right_neighbor->get_iset('pos')||'') eq 'verb') {
            $right_neighbor->set_parent($auxc);
        }


	#re-hang even if the right neighbor is coordination of verbs
	if($right_neighbor and ($right_neighbor->afun eq 'Coord')) {

	    my $verbs = grep {($_->get_iset('pos')||'') eq 'verb' and $_->is_member == 1} $right_neighbor->get_children();
	    if( $verbs > 0) {
		$right_neighbor->set_parent($auxc);
	    }
	}

    }

}



1;

=over

=item Treex::Block::HamleDT::HU::Harmonize

Converts Hungarian trees from CoNLL 2007 (Szeged Treebank) to the style of
HamleDT (Prague).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
