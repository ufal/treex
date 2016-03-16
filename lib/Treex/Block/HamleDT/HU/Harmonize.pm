package Treex::Block::HamleDT::HU::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'hu::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



# /net/data/conll/2007/hu/doc/README
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->attach_final_punctuation_to_root($root);
    $self->fix_predicates_of_parentheses($root);
    $self->rehang_subconj($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# for deprels see /net/data/conll/2007/hu/doc/dep_szegedtreebank_en.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
    foreach my $node (grep {not $_->is_coap_root and not $_->deprel} $root->get_descendants)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        # my $subpos = $node->get_iset('subpos'); # feature deprecated
        my $ppos   = $parent ? $parent->get_iset('pos') : '';
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
            $deprel = 'Obj';
        }
        # ADV = adverbial phrase (például, még, már, csak, mintegy)
        elsif($deprel eq 'ADV')
        {
            $deprel = 'Adv';
        }
        # ATT = attribute (több, első, az, két, új)
        elsif($deprel eq 'ATT')
        {
            # Sometimes even a verb (clause) modifying another verb is labeled ATT.
            if($ppos eq 'verb')
            {
                $deprel = 'Adv';
            }
            else
            {
                $deprel = 'Atr';
            }
        }
        # AUX = auxiliary verb (volna)
        # The only word with this label is "volna", 3rd person singular conditional present indefinite of "van" ("be, exist, have").
        # When combined with past tense indicative of a finite, content verb, "volna" creates past tense conditional.
        # (Non-past conditional has synthetic forms.)
        elsif($deprel eq 'AUX')
        {
            $deprel = 'AuxV';
        }
        # CONJ = conjunction (és, hogy, is, mint, ha)
        # This label is used both for coordinating conjunctions (e.g. "és" = "and") and subordinating conjunctions (e.g. "hogy" = "that").
        elsif($deprel eq 'CONJ')
        {
            if($node->is_coordinator())
            {
                $deprel = 'AuxY';
                $node->wild()->{coordinator} = 1;
            }
            else # subordinating conjunction
            {
                $deprel = 'AuxC';
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
            $deprel = 'Pred'; ###!!!
        }
        # DET = determiner (article) (a, az, egy)
        elsif($deprel eq 'DET')
        {
            ###!!! In the future, we may want to change this to "AuxA" but now the "AuxA" label is unsupported.
            $deprel = 'Atr';
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
            $deprel = 'Adv';
        }
        # Infinitive as argument of another verb (tenni, tartani, elérni, tudni, fizetni)
        # partnerek készülnek megszavazni = lit. partners are-prepared to-vote
        # kívánja demonstrálni = wishes to demonstrate
        # tudni kell = need to know (lit. to-know need)
        elsif($deprel eq 'INF')
        {
            $deprel = 'Obj';
        }
        # NEG = negation (nem, sem, ne, se)
        elsif($deprel eq 'NEG')
        {
            $deprel = 'Neg';
        }
        # NP = noun phrase
        # It is always attached to either a verb, or a conjunction (probably coordination of noun phrases).
        # It is not clear why it is not labeled as either subject (if it is in nominative) or object.
        # Example: amelynek, annak, ennek, és, képes
        elsif($deprel eq 'NP')
        {
            if($node->get_iset('case') eq 'nom')
            {
                $deprel = 'Sb';
            }
            else
            {
                $deprel = 'Obj';
            }
        }
        # PP = postposition (szerint, után, között, által, alatt) (according to, after, between, by, during)
        # This label says that the node is postposition but it does not reveal its function towards its parent.
        # Unlike in PDT, the function is not labeled at the child of the postposition either.
        # The child (noun) is always labeled as attribute but the postpositional phrase is always attached to verb.
        ###!!! Later on we should relabel the child of the postposition to "Adv"!
        elsif($deprel eq 'PP')
        {
            $deprel = 'AuxP';
        }
        # PRED = predicate NP (az, képes, hajlandó, több, forint)
        # This may be an adjective or noun attached to a form of a copula verb ("to be", "to become" and similar): "voltak jók" = "were good"
        # However, some occurrences are different: modality is added to the parent verb (which can hardly be described as copula):
        # képes felmutatni = can show (felmutatni is infinitive "to show"; képes is adjective "able", attached to felmutatni as PRED)
        # volt képes választani = was able to choose (volt means "was" and it is parent of both képes "able" and választani "to choose")
        elsif($deprel eq 'PRED')
        {
            ###!!! We should later reshape the constructions with "képes".
            $deprel = 'Pnom';
        }
        # PREVERB = preverb (meg, el, ki, be, fel)
        # Despite being called preverb in the documentation, I always saw these elements after the verb to which they were attached.
        # They are particles that modify the meaning of the verb.
        elsif($deprel eq 'PREVERB')
        {
            $deprel = 'AuxT';
        }
        # PUNCT = punctuation character (, . — " :)
        # AuxX should be used for commas, AuxG for other graphic symbols.
        elsif($deprel eq 'PUNCT')
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
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
            $deprel = 'Pred';
        }
        # QUE = query word
        # Only these three: -e, vajon, ugye
        # "ugye" is adverb and means "isn't it" (Wiktionary)
        # "vajon" is adverb and means "I wonder [if]" (Wiktionary)
        # "-e" is interrogative particle attached to predicates: Nem tudom, voltál-e már Budapesten. - I don't know if you've ever been in Budapest. (Wiktionary)
        elsif($deprel eq 'QUE')
        {
            ###!!! If we convert it to AuxC we should later reshape the tree so that it governs the verb (now it is attached to the verb).
            $deprel = 'AuxC';
        }
        # SUBJ = subject (aki, amely, az, ez, kormány)
        elsif($deprel eq 'SUBJ')
        {
            $deprel = 'Sb';
        }
        # UK = unknown
        # There are only three occurrences in the corpus.
        elsif($deprel eq 'UK')
        {
            $deprel = 'ExD';
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
            $deprel = 'Adv';
        }
        # XP = inserted fragment
        # 271 occurrences in the corpus.
        elsif($deprel eq 'XP')
        {
            ###!!! we may also want to set is_parenthesis_root to 1 but we should investigate the examples.
            $deprel = 'ExD';
        }
        $node->set_deprel($deprel);
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
        my $parent = $node->parent();
        my $grandparent = $parent->parent();
        my $rsibling = $node->get_right_neighbor();
        # The "not only" part of compound conjunction "not only ... but" should be written as one word, "nemcsak".
        # Cases like "nem csak" and "nem-csak" are tagged as typos. The real part of speech is thus not visible, which results in other errors.
        if($node->is_typo() || $node->is_foreign())
        {
            if($node->form() eq 'nem-csak')
            {
                $node->set_deprel('AuxY');
            }
            elsif($node->form() eq 'nem' && $parent->form() eq 'csak')
            {
                $node->set_deprel('Neg');
                $parent->set_deprel('AuxY');
            }
        }
        # tudni kell, hogy ... wrong nonprojective attachment
        elsif($grandparent && !$grandparent->is_root() &&
              $parent->form() eq 'tudni' && $grandparent->form() eq 'kell' &&
              $parent->precedes($grandparent) && $parent->deprel() ne 'Pred' && $grandparent->deprel() eq 'Pred' &&
              $grandparent->precedes($node) &&
              !$node->is_member())
        {
            my @gpc = $grandparent->get_children({following_only => 1});
            my ($hogy) = grep {$_->form() eq 'hogy'} (@gpc);
            if(defined($hogy))
            {
                $node->set_parent($hogy);
                $node->set_deprel('Obj') if($node->deprel() eq 'Pred');
            }
            else
            {
                $node->set_parent($grandparent);
            }
        }
        # S bár = Although
        # In theory this could be caught later with the other subordinating conjunctions
        # but there is one sentence where it interacts with a coordinating conjunction and it goes wrong.
        elsif($node->ord() == 2 && $node->form() eq 'bár' && $node->precedes($parent) && $parent->is_verb() &&
              $rsibling && $rsibling->is_verb())
        {
            my $comma = $rsibling->get_right_neighbor();
            if($comma && $comma->form() eq ',')
            {
                $comma->set_parent($node);
            }
            $rsibling->set_parent($node);
            $node->set_deprel('AuxC');
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



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects Tesnière style as
# it is found in the Szeged treebank. Nested coordination is not expected and
# some instances may not be recognizable correctly.
# - conjuncts, conjunctions and commas are separately attached to the parent of
#   the coordination
# - no formal marking of conjuncts
# - conjunctions have wild->{coordinator} ###!!!
# The method assumes that nothing has been normalized yet. In particular it
# assumes that there are no AuxP/AuxC afuns (there are PrepArg/SubArg instead).
# Thus the method does not call $node->set/get_real_afun().
#------------------------------------------------------------------------------
sub detect_szeged
{
    my $self = shift;
    my $node = shift; # suspected root node of coordination
    # $nontop is mentioned for reasons of compatibility with other detection functions.
    # It is not really needed here as there will be no recursion.
    my $nontop = shift; # other than top level of recursion?
    log_fatal("Missing node") unless(defined($node));
    my $top = !$nontop;
    ###!!!DEBUG
    my $debug = 0;
    if($debug)
    {
        my $form = $node->form();
        $form = '' if(!defined($form));
        if($top)
        {
            $node->set_form("T:$form");
        }
        else
        {
            $node->set_form("X:$form");
        }
    }
    ###!!!END
    # Looking for Tesnièrian coordination starts at the conjunction.
    # Once we see a conjunction we look at its siblings and check whether they have matching dependency labels.
    return unless($node->wild()->{coordinator});
    my @punctuation;
    my $lsibling = skip_commas($node->get_left_neighbor(), 'left', \@punctuation);
    my $rsibling = skip_commas($node->get_right_neighbor(), 'right', \@punctuation);
    if($lsibling && $rsibling && $lsibling->afun() eq $rsibling->afun() && $lsibling->afun() ne 'Coord')
    {
        # We have found a conjunction and two conjuncts around it.
        # Let's add them to the coordination.
        my $symbol = 0;
        my @partmodifiers = $node->children();
        $self->add_delimiter($node, $symbol, @partmodifiers);
        my $orphan = 0;
        foreach my $conjunct ($lsibling, $rsibling)
        {
            my @partmodifiers = $conjunct->children();
            $self->add_conjunct($conjunct, $orphan, @partmodifiers);
        }
        # Save the skipped commas (and possibly other punctuation).
        $symbol = 1;
        foreach my $delimiter (@punctuation)
        {
            # Hopefully the comma has no children but just in case.
            my @partmodifiers = $delimiter->children();
            $self->add_delimiter($delimiter, $symbol, @partmodifiers);
        }
        # Save the relation of the coordination to its parent.
        $self->set_parent($node->parent());
        $self->set_afun($lsibling->afun());
        $self->set_is_member($node->is_member());
        # Are there additional conjuncts to the left, separated by punctuation?
        my @candidates = $lsibling->get_siblings({preceding_only => 1});
        while(scalar(@candidates)>=2)
        {
            my $comma = pop(@candidates);
            my $conjunct = pop(@candidates);
            if($comma->form() =~ m/^[,;:—]$/ && $conjunct->afun() eq $lsibling->afun() && !$comma->is_member() && !$conjunct->is_member())
            {
                # Hopefully the comma has no children but just in case.
                my @partmodifiers = $comma->children();
                $self->add_delimiter($comma, 1, @partmodifiers);
                @partmodifiers = $conjunct->children();
                $self->add_conjunct($conjunct, 0, @partmodifiers);
            }
            else
            {
                last;
            }
        }
    }
    elsif($node->ord()==1 && defined($node->parent()) && defined($node->parent()->parent()) && $node->parent()->parent()->is_root())
    {
        # Deficient (single-conjunct) sentence coordination.
        my $conjunct = $node->parent();
        my $root = $conjunct->parent();
        $self->set_parent($root);
        $self->set_afun($conjunct->afun());
        $self->set_is_member(undef);
        $self->add_delimiter($node, 0, $node->children());
        $self->add_conjunct($conjunct, 0, grep {$_!=$node} ($conjunct->children()));
    }
    else
    {
        # The Szeged treebank is not always strictly Tesnièrian with respect to coordination.
        # Some cases (especially coordinate main predicates) are analyzed as shallow Prague-like structures, i.e. conjunction heads the predicates.
        # If we failed using the conditions above, perhaps we are dealing with this sort of coordinate structure.
        my (@left_conjuncts)  = grep {!$_->is_punctuation() && $_->precedes($node)} $node->children();
        my (@right_conjuncts) = grep {!$_->is_punctuation() && !$_->precedes($node)} $node->children();
        if(scalar(@left_conjuncts)==1 && scalar(@right_conjuncts)==1 && $left_conjuncts[0]->afun() eq $right_conjuncts[0]->afun() && $left_conjuncts[0]->afun() ne 'Coord')
        {
            my $symbol = 0;
            # The only children of the conjunction are the two conjuncts and possible additional punctuation.
            # There are no other private modifiers of the conjunction.
            $self->add_delimiter($node, $symbol);
            my @punctuation = grep {$_->is_punctuation()} $node->children();
            foreach my $delimiter (@punctuation)
            {
                # Hopefully the comma has no children but just in case.
                my @partmodifiers = $delimiter->children();
                $self->add_delimiter($delimiter, $symbol, @partmodifiers);
            }
            my $orphan = 0;
            foreach my $conjunct (@left_conjuncts, @right_conjuncts)
            {
                my @partmodifiers = $conjunct->children();
                $self->add_conjunct($conjunct, $orphan, @partmodifiers);
            }
            # Save the relation of the coordination to its parent.
            $self->set_parent($node->parent());
            $self->set_afun($left_conjuncts[0]->afun());
            $self->set_is_member($node->is_member());
        }
    }
    # If this is the top level, we now know all we can.
    # It's time for a few more heuristics.
    if($top)
    {
        $self->reconsider_distant_private_modifiers();
    }
    # Other detection methods return (unless this is $top) the list of modifiers to the upper level,
    # where it is needed when the current node is added as a participant.
    # In this style however there is no recursion and no nested coordinations so we do not have to return anything.
    return;
}



#------------------------------------------------------------------------------
# The detect_coordination() method above does not recognize coordination that
# lacks conjunction. Many sentences in the Szeged Treebank have coordinate
# predicates that are delimited just by punctuation (commas, sometimes colon
# and others). We must detect this sort of coordination separately. We must
# also take care of processing coordinations we find because the superordinate
# class is not prepared for us having two different detect_coordination()
# methods.
#------------------------------------------------------------------------------
sub restructure_coordinate_predicates
{
    my $self = shift;
    my $root = shift;
    my $debug = shift;
    # We require that the list of nodes be ordered.
    # The predicate structure is right-branching and we must process it top-down, i.e. also left-to-right.
    my @nodes = $root->get_descendants({ordered => 1});
    map {$_->wild()->{processed} = 0;} @nodes;
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred' && !$node->wild()->{processed})
        {
            my $coordination;###!!! = new Treex::Core::Coordination;
            $coordination->set_parent($node->parent());
            $coordination->set_deprel('Pred');
            $coordination->set_is_member($node->is_member());
            my (@modifiers) = recursively_add_coordinate_predicates($coordination, $node);
            # If we recognized coordination, add this node as conjunct too.
            if($coordination->get_conjuncts())
            {
                $coordination->add_conjunct($node, 0, @modifiers);
                # Coordination detected. Change the tree to encode the coordination in the required way.
                $coordination->shape_prague();
            }
        }
    }
    # There are still unrecognized coordinations with conjunction.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred' && $node->is_coordinator() && grep {$_->get_real_deprel() eq 'Pred'} ($node->children()))
        {
            my $coordination = new Treex::Core::Coordination;
            $coordination->set_parent($node->parent());
            $coordination->set_deprel('Pred');
            $coordination->set_is_member($node->is_member());
            $coordination->add_delimiter($node);
            my @children = $node->children();
            my @conjuncts = grep {$_->get_real_afun() eq 'Pred'} (@children);
            my @delimiters = grep {$_->deprel() eq 'AuxX'} (@children);
            my @smodifiers = grep {$_->get_real_afun() ne 'Pred' && $_->deprel() ne 'AuxX'} (@children);
            foreach my $conjunct (@conjuncts)
            {
                $coordination->add_conjunct($conjunct, 0, $conjunct->children());
            }
            foreach my $delimiter (@delimiters)
            {
                $coordination->add_delimiter($delimiter, 1);
            }
            foreach my $modifier (@smodifiers)
            {
                $coordination->add_shared_modifier($modifier);
            }
            $coordination->shape_prague();
        }
    }
    # Due to gradual processing in previous steps, coordinate clauses may now look as a hierarchic structure of nested coordinations.
    # Merge them to one flat coordination.
    foreach my $node (@nodes)
    {
        if($node->is_coap_root() && !$node->is_member() && $node->get_real_afun() eq 'Pred')
        {
            my $coordination = new Treex::Core::Coordination;
            $coordination->detect_prague($node);
            dissolve_nested_coordinations($coordination);
        }
    }
    # In some sentences, there are clauses that appear to be coordinate and subordinate at the same time.
    # Such a clause is headed by the subordinating conjunction "hogy" ("that") and it takes part in the chain of predicates in the upper levels of the tree.
    # Hogy may even be the ROOT (child of the root) if this is the first clause in the sentence.
    # Both the conjunction and the verb were labeled "Pred"; "hogy" was eventually relabeled "AuxC".
    # Now the children of "hogy" should no longer have the label "Pred". "Obj" might be appropriate if the clause modifies a verb of saying.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred' && !$node->parent()->is_root() && lc($node->parent()->form()) eq 'hogy')
        {
            $node->set_deprel('Obj');
        }
    }
    # Sometimes a Pred node should have been attached to a preceding subordinating conjunction (usually "hogy")
    # but it skips it and without any apparent reason is attached nonprojectively to something farther to the left.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred' && !$node->parent()->is_root() && !$node->is_member() && $node->parent()->precedes($node))
        {
            my $parent = $node->parent();
            # Is there a subordinating conjunction between the node and its parent?
            my @subs = grep {$_->is_subordinator() && $_->precedes($node) && $parent->precedes($_)} @nodes;
            # We are looking for nonprojective dependencies. Exclude conjunctions that depend (even indirectly) on the parent.
            # Later addition: left sibling of the predicate would also do.
            @subs = grep {!$_->is_descendant_of($parent)} @subs;
            my $lsibling = $node->get_left_neighbor();
            if(!@subs && $lsibling && $parent->precedes($lsibling) && $lsibling->is_subordinator())
            {
                @subs = ($lsibling);
            }
            if(@subs)
            {
                # If there are more than one conjunction, take the rightmost one.
                my $conjunction = $subs[-1];
                # Reattach all predicates and all nodes between them.
                # We could catch the other predicates later but it would be difficult to recognize the commas that separate them.
                my @siblings = $parent->get_children({ordered => 1});
                my @preds = grep {$conjunction->precedes($_) && $_->deprel() eq 'Pred'} @siblings;
                my $min = $preds[0]->ord();
                my $max = $preds[-1]->ord();
                my @to_move = grep {$_->ord() >= $min && $_->ord() <= $max} @siblings;
                foreach my $ntm (@to_move)
                {
                    $ntm->set_parent($conjunction);
                    $ntm->set_deprel('Obj') if($ntm->deprel() eq 'Pred');
                    $ntm->set_is_member(undef);
                }
            }
        }
    }
    # Get rid of the remaining predicates that are not attached to the root.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred')
        {
            my ($eparent) = $node->get_eparents();
            if(!$eparent->is_root())
            {
                # This node is not attached to the root, thus it must not be labeled Pred.
                # It is possible that it deserves the label and it ought to be attached elsewhere
                # but we have not been able to find where.
                # So we will estimate a label that matches the current attachment.
                my $parent = $node->parent();
                my $ppos = $parent->get_iset('pos');
                if($parent->is_subordinator())
                {
                    $node->set_deprel('Obj');
                }
                elsif($ppos =~ m/^(noun|num)$/)
                {
                    $node->set_deprel('Atr');
                }
                elsif($ppos =~ m/^(verb|adj|adv)$/)
                {
                    $node->set_deprel('Adv');
                }
                else
                {
                    $node->set_deprel('ExD');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Recursive function called from restructure_coordinate_predicates().
#------------------------------------------------------------------------------
sub recursively_add_coordinate_predicates
{
    my $coordination = shift;
    my $mainpred = shift;
    $mainpred->wild()->{processed} = 1;
    # Get separately children to the left and to the right.
    # We will search for Preds only to the right.
    my @lchildren = $mainpred->get_children({preceding_only => 1});
    my @rchildren = $mainpred->get_children({following_only => 1});
    # Look at children to the right. Any Pred among them?
    my @preds;
    my @commas;
    while(scalar(@rchildren)>=2)
    {
        my $pred = $rchildren[$#rchildren];
        my $comma = $rchildren[$#rchildren-1];
        if($comma->form() =~ m/^[,;:—]$/ && $pred->get_real_afun() eq 'Pred')
        {
            # The dependent predicate should not have been processed yet because we are processing the nodes left-to-right.
            log_warn("Processing a predicate the second time.") if($pred->wild()->{processed});
            $pred->wild()->{processed} = 1;
            push(@preds, $pred);
            push(@commas, $comma);
            # Remove the two nodes from the list of children (we will return the list as modifiers).
            splice(@rchildren, $#rchildren-1);
        }
        else
        {
            last;
        }
    }
    if(@preds && @commas)
    {
        # Look at each Pred whether it has its own dependent Preds.
        foreach my $pred (@preds)
        {
            my (@modifiers) = recursively_add_coordinate_predicates($coordination, $pred);
            # Now we know which children of the dependent Pred are modifiers and can add it as conjunct.
            $coordination->add_conjunct($pred, 0, @modifiers);
        }
        # Add the commas as delimiters.
        foreach my $comma (@commas)
        {
            $coordination->add_delimiter($comma, 1, $comma->children());
        }
    }
    # If we found any dependent predicate and punctuation that delimits it, these nodes have been removed from the list of children.
    # The remaining children are modifiers. We return them so that the upper level can use them to add $mainpred as conjunct.
    return (@lchildren, @rchildren);
}



#------------------------------------------------------------------------------
# Recursively finds all nested coordinations, i.e. conjuncts that are
# themselves heads of coordination, and dissolves them, i.e. all participants
# of the nested coordination become direct participants of the main
# coordination.
#
# It would be nice to have this function as a method of the Coordination class.
# However, that will first require to rewrite Coordination so that it can have
# any phrase, not just a node, as conjunct. Otherwise the function depends on
# the (Prague) style in which the coordination is encoded in the dependency
# tree.
#------------------------------------------------------------------------------
sub dissolve_nested_coordinations
{
    my $maincoord = shift;
    my @conjuncts = $maincoord->get_conjuncts();
    foreach my $conjunct (@conjuncts)
    {
        if($conjunct->deprel() eq 'Coord')
        {
            $maincoord->remove_participant($conjunct);
            my $subcoord = new Treex::Core::Coordination;
            $subcoord->detect_prague($conjunct);
            dissolve_nested_coordinations($subcoord);
            my @subconjuncts = $subcoord->get_conjuncts();
            foreach my $subconjunct (@subconjuncts)
            {
                ###!!! We ought to distinguish orphans from normal conjuncts and port this information upwards.
                ###!!! It is not needed for the coordinate predicates in Szeged Treebank but it should not be ignored in general.
                my @pmodifiers = $subcoord->get_private_modifiers($subconjunct);
                $maincoord->add_conjunct($subconjunct, 0, @pmodifiers);
            }
            my @subdelimiters = $subcoord->get_delimiters();
            foreach my $delimiter (@subdelimiters)
            {
                ###!!! We ought to distinguish symbols from conjunctions!
                ###!!! We should ask the nested coordination about it and not look at deprels here!
                my $symbol = $delimiter->deprel() =~ m/^Aux[GX]$/;
                my @pmodifiers = $subcoord->get_private_modifiers($delimiter);
                $maincoord->add_delimiter($delimiter, $symbol, @pmodifiers);
            }
            my @subsharedmodifiers = $subcoord->get_shared_modifiers();
            foreach my $modifier (@subsharedmodifiers)
            {
                $maincoord->add_shared_modifier($modifier);
            }
        }
    }
    $maincoord->shape_prague();
}



#------------------------------------------------------------------------------
# Finds predicates inside brackets. These should not be labeled Pred but ExD.
#------------------------------------------------------------------------------
sub fix_predicates_of_parentheses
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'Pred')
        {
            # Subordinating conjunction must not be labeled Pred, not even if its parent is root.
            # The conjunction should be labeled AuxC. Its child can be Pred if its effective parent (skipping any AuxC and Coord) is root.
            # In the original trees there are many cases where both the conjunction and the verb under it are labeled Pred. We must fix it!
            if($node->is_subordinator())
            {
                $node->set_deprel('AuxC');
            }
            # The node can be labeled Pred only if its effective parent is the root.
            my ($eparent) = $node->get_eparents();
            if(!$eparent->is_root())
            {
                # One of the reasons why extra Preds appear in the Szeged Treebank is parenthesis.
                # We will not recognize parenthesis if it is delimited by dashes instead of brackets.
                my @lpar = grep {$_->ord() < $node->ord() && $_->form() eq '('} @nodes;
                my @rpar = grep {$_->ord() > $node->ord() && $_->form() eq ')'} @nodes;
                my @ldash = grep {$_->ord() < $node->ord() && $_->form() eq '—'} @nodes;
                my @rdash = grep {$_->ord() > $node->ord() && $_->form() eq '—'} @nodes;
                if(@lpar && @rpar || @ldash && @rdash)
                {
                    $node->set_deprel('ExD');
                    $node->set_is_parenthesis_root(1);
                }
                # A special case of the above: parenthesis delimited by m-dashes, the contents headed by the adverb "mint" ("than"),
                # labeled ExD, its child is a verb labeled Pred. We will relabel the verb ExD too.
                elsif($eparent->deprel() eq 'ExD')
                {
                    $node->set_deprel('ExD');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Some subordinating conjunctions are attached as siblings of their subordinate
# clauses, others govern the clauses. We want all to govern the clauses.
#------------------------------------------------------------------------------
sub rehang_subconj
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $auxc (grep {$_->deprel eq 'AuxC'} @nodes)
    {
        my $left_neighbor = $auxc->get_left_neighbor();
        if ($left_neighbor and $left_neighbor->form eq ',')
        {
            $left_neighbor->set_parent($auxc);
        }
        my $right_neighbor = $auxc->get_right_neighbor();
        if ($right_neighbor and $right_neighbor->is_verb() && !$auxc->is_member() && !$right_neighbor->is_member())
        {
            $right_neighbor->set_parent($auxc);
        }
        # Reattach even if the right neighbor is coordination of verbs.
        if ($right_neighbor and $right_neighbor->is_coap_root() and !$auxc->is_member() and !$right_neighbor->is_member())
        {
            my $verbs = grep {$_->is_verb() && $_->is_member()} $right_neighbor->children();
            if( $verbs > 0 )
            {
                $right_neighbor->set_parent($auxc);
            }
        }
        # Some predicates of subordinate clauses are still labeled Pred.
        my ($eparent) = $auxc->get_eparents();
        if ($right_neighbor && $right_neighbor->parent()==$auxc && $right_neighbor->get_real_afun() eq 'Pred' && !$eparent->is_root())
        {
            $right_neighbor->set_real_afun('Obj');
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
