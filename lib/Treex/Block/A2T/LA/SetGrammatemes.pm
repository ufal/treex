package Treex::Block::A2T::LA::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $lex_anode = $t_node->get_lex_anode;
    my @aux_anodes = $t_node->get_aux_anodes;
    my $functor = $t_node->functor;
    my $parent_lex_anode = $lex_anode->get_parent;  
    my $lex_form = $lex_anode->form;
    my $lex_lemma = $lex_anode->lemma;
    my $lex_tag = $lex_anode->tag;
    my $lex_afun = $lex_anode->afun;
    my $lex_member = $lex_anode->is_member;
    my $parent_form = $parent_lex_anode->form;
    my $parent_lemma = $parent_lex_anode->lemma;
    my $parent_tag = $parent_lex_anode->tag;
    my $parent_afun = $parent_lex_anode->afun;

    my @parent_children = $parent_lex_anode->get_children({ordered => 1});
    my %is_lemma_of_a_parentchild;
    foreach my $parentchild ($parent_lex_anode->get_children()) {
        $is_lemma_of_a_parentchild{$parentchild->lemma} = 1;
    }

    my $grandparent_anode;
    my $grandparent_lemma;
    my $grandparent_tag;
    my $grandparent_afun;
    if (defined $parent_lex_anode->get_parent()) {
        $grandparent_anode = $parent_lex_anode->get_parent();
        $grandparent_lemma = $grandparent_anode->lemma;
        $grandparent_tag = $grandparent_anode->tag;
        $grandparent_afun = $grandparent_anode->afun;
    }

    my %is_afun_of_a_child;
    foreach my $child ($lex_anode->get_children()) {
        $is_afun_of_a_child{$child->afun} = 1;
    }


# TODO and NOTES:
#
# TODO Assign gram/verbmod 'ind' to participles (tag /^2/) with a child with afun AuxV and tag /^3..A/ ("dictum est-fuit" etc.)
#
# NOTE: gram/sempos/n.denot: NO sempos/n.denot.neg is presently assigned. Further investigation is needed. The same holds for sempos/adj.denom
#
# NOTE: presently, words with tag ^1 are assigned by default sempos 'n.denot': this must be carefully checked by hand
#
# NOTE: the grammatemes 'number' and 'gender' are assigned to semantic nouns/pronouns ONLY (sempos eq "n.*"). Presently, they are assigned to all
# the words with tags '^1.*'. So, adj. are included as well. Adj. should have number/gender 'inher': this must be done!
# Anyway: check better on the guidelines how the 'inher' value for number/gender is assigned!
#
# DOMANDA [ALDO]: verificare l'attribuzione delle sempos 'adv...'
# DOMANDA: quale valore del gram/deontmod assegnare agli infiniti dipendenti dai verbi modali "soleo-incipio-desino"?


    
    # by default, the 'enunc' sentmod attribute is assigned to all the Pred nodes
    # NB! This is not a grammateme, but an attribute
        if ($lex_afun eq 'Pred') {
            $t_node->set_attr('sentmod', 'enunc');
    
    }        

    # assign sentmod/enunc to those infinitives depending on modal verbs with afun Pred
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && (grep $parent_lemma eq $_, qw(possum debeo volo nolo malo soleo incipio desino intendo))
    && $parent_afun eq 'Pred') {
        $t_node->set_attr('sentmod', 'enunc');
    }

    # assign sentmod/enunc to those infinitives depending on modal verbs with afun Pred via Coord (possum facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $lex_member && $parent_afun eq 'Coord'
        && (grep $grandparent_lemma eq $_, qw(possum debeo volo nolo malo soleo incipio desino intendo))
        && $grandparent_afun eq 'Pred') {
        $t_node->set_attr('sentmod', 'enunc');
    }  
  

    # the 'f' value of tfa is assigned
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(non adhuc etiam item)) {
            $t_node->set_attr('tfa', 'f');
    }

    # the 'f' value of tfa is assigned, if afun = 'AuxZ'
    # NB! This is not a grammateme, but an attribute
        if ($lex_afun eq 'AuxZ' && ($lex_lemma eq 'et' || $lex_lemma eq 'nec')) {
            $t_node->set_attr('tfa', 'f');
    }

    # the 'f' value of tfa is assigned to a number of forms
    # NB! This is not a grammateme, but an attribute
        if ($lex_afun eq 'Adv' && (grep $lex_form eq $_, qw(solum))) {
            $t_node->set_attr('tfa', 'f');
    }

    # the 't' value of tfa is assigned
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(deinde enim ergo ideo igitur nam quidem tunc unde vero inde hinc)) {
            $t_node->set_attr('tfa', 't');
    }

    # the 'c' value of tfa is assigned
    # NB! This is not a grammateme, but an attribute
        if (grep $lex_lemma eq $_, qw(tamen)) {
            $t_node->set_attr('tfa', 'c');
    }


    # the #Comma t-lemma is assigned to punctuations acting as Coord, or Apos
    # NB! This is not a grammateme, but an attribute
        if ((grep $lex_lemma eq $_, (',', ';', ':')) && (grep $lex_afun eq $_, qw(Coord Apos))) {
            $t_node->set_attr('t_lemma', '#Comma');
    }

    # '3' on the first (verbs): deontmod 'decl'
        if ($lex_tag =~ /^3/) {
            $t_node->set_gram_deontmod('decl');
    }

    # '2' on the first and AuxV child (compound verbs): deontmod 'decl'
        if ($lex_tag =~ /^2/ && $is_afun_of_a_child{AuxV}) {
            $t_node->set_gram_deontmod('decl');
    }

    # assign deontmod/poss to those infinitives depending on modal verb 'possum'
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $parent_lemma eq 'possum') {
        $t_node->set_gram_deontmod('poss');
    }

    # assign deontmod/poss to those infinitives depending on modal verb 'possum' via Coord (possum facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $lex_member && $parent_afun eq 'Coord'
        && $grandparent_lemma eq 'possum') {
        $t_node->set_gram_deontmod('poss');
    }

    # assign deontmod/deb to those infinitives depending on modal verb 'debeo'
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $parent_lemma eq 'debeo') {
        $t_node->set_gram_deontmod('deb');
    }

    # assign deontmod/deb to those infinitives depending on modal verb 'oportet'
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Sb' && $parent_lemma eq 'oportet') {
        $t_node->set_gram_deontmod('deb');
    }

    # assign deontmod/deb to those infinitives depending on 'oportet' via Coord (oportet facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Sb' && $lex_member && $parent_afun eq 'Coord'
        && $grandparent_lemma eq 'oportet') {
        $t_node->set_gram_deontmod('deb');
    }

    # assign deontmod/deb to those infinitives depending on 'necesse est'
    # TODO: to assign deontmod/deb to coordinated infinitives depending on "necesse est"(necesse est facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Sb' && $parent_lemma eq 'sum' && $is_lemma_of_a_parentchild{necesse}) {
        $t_node->set_gram_deontmod('deb');
    }

    # assign deontmod/deb to those infinitives depending on modal verb 'debeo' via Coord (debeo facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $lex_member && $parent_afun eq 'Coord'
        && $grandparent_lemma eq 'debeo') {
        $t_node->set_gram_deontmod('deb');
    }

    # assign deontmod/vol to those infinitives depending on modal verb 'volo/nolo/malo/intendo'
    # negative 'nolo' is assigned deontmod/vol according to 6.4.2 (Guidelines for TG annotation)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && (grep $parent_lemma eq $_, qw(volo nolo malo intendo))) {
        $t_node->set_gram_deontmod('vol');
    }

    # assign deontmod/vol to those infinitives depending on modal verb 'volo/nolo/malo/intendo' via Coord (volo facere et dicere)
    if ($lex_tag =~ /^3..[HQ]/ && $lex_afun eq 'Obj' && $lex_member && $parent_afun eq 'Coord'
        && (grep $parent_lemma eq $_, qw(volo nolo malo intendo))) {
        $t_node->set_gram_deontmod('vol');
    }

    # '3' on the first: dispositional modality "disp0" ("no dispositional modality")
        if ($lex_tag =~ /^3/) {
            $t_node->set_gram_dispmod('disp0');
    }

    # '3' on the first and [HQ] mood (infinitives): dispositional modality 'nil' ("not applicable")
        if ($lex_tag =~ /^3..[HQ]/) {
            $t_node->set_gram_dispmod('nil');
    }

    # '2' on the first and [DM] mood (participles): dispositional modality "disp0" ("no dispositional modality")
        if ($lex_tag =~ /^2..[DM]/) {
            $t_node->set_gram_dispmod('disp0');	
    }

    # '2' on the first and [ENO] mood (gerunds and gerundives): dispositional modality 'nil' ("not applicable")
        if ($lex_tag =~ /^2..[ENO]/) {
            $t_node->set_gram_dispmod('nil');	
    }

    # '3' on the first: no resultative meaning ("res0")
        if ($lex_tag =~ /^3/) {
            $t_node->set_gram_resultative('res0');
    }

    # '2' on the first and AuxV child: no resultative meaning ("res0")
        if ($lex_tag =~ /^2/ && $is_afun_of_a_child{AuxV}) {
            $t_node->set_gram_resultative('res0');	
    }

    # '3' on the first and '1' on the fifth position: tense "simultaneous event"
        if ($lex_tag =~ /^3...1/) {
            $t_node->set_gram_tense('sim');	
    }	
    
    # '3' on the first and '[245]' on the fifth position: tense "anterior event"
        if ($lex_tag =~ /^3...[245]/) {
            $t_node->set_gram_tense('ant');	
    }

    # '3' on the first and '[36]' on the fifth position: tense "posterior event"
        if ($lex_tag =~ /^3...[36]/) {
            $t_node->set_gram_tense('post');	
    }

    # '2' on the first and '[ENO]' mood (gerunds and gerundives): tense 'nil' ("not applicable")
        if ($lex_tag =~ /^2..[ENO]/) {
            $t_node->set_gram_tense('nil');	
    }

    # '3' on the first and '[AJ]' on the fourth position: verbmod 'indicative'
    if ($lex_tag =~ /^3..[AJ]/) {
            $t_node->set_gram_verbmod('ind');
        }

    # '3' on the first and [HQ] mood (infinitives): verbmod 'nil' ("not applicable")
        if ($lex_tag =~ /^3..[HQ]/) {
            $t_node->set_gram_verbmod('nil');
    }

    # '2' on the first and [ENODM] mood (gerunds and gerundives, participles): verbmod 'nil' ("not applicable")
        if ($lex_tag =~ /^2..[ENODM]/) {
            $t_node->set_gram_verbmod('nil');
    }

    # '3' on the first: iterativeness "no iterative meaning" (it0)
    # by default, all the semantic verbs are tagged with 'it0' iterativeness. Exceptions must be corrected manually
        if ($lex_tag =~ /^3/) {
            $t_node->set_gram_iterativeness('it0');	
    }

    # '2' on the first and AuxV child: iterativeness "no iterative meaning" (it0)
        if ($lex_tag =~ /^2/ && $is_afun_of_a_child{AuxV}) {
            $t_node->set_gram_iterativeness('it0');	
    }

    # '3' on the first: sempos 'v' (verb)
        if ($lex_tag =~ /^[23]/) {
            $t_node->set_gram_sempos('v');	
    }

    # !! [by default rule] '1' on the first: sempos 'n.denot'. This must be checked manually!!
        if ($lex_tag =~ /^1/) {
            $t_node->set_gram_sempos('n.denot');	
    }

    # '2' on the first and AuxV child: sempos 'v' (verb)
        if ($lex_tag =~ /^2/ && $is_afun_of_a_child{AuxV}) {
            $t_node->set_gram_sempos('v');	
    }

    # '2' on the first and 'O' on the fourth position (gerundives): deontmod 'hrt' (obligatory event)
    # EXCEPTION to TG Guidelines (6.2.1): by rule, 'adj.denot' are assigned only the 'degcmp' and the 'negation' grammatemes,
    # WHILE here also the 'deontmod' grammateme is asigned to a 'adj.deont', because gerundives are present in Latin but not in Czech 
        if ($lex_tag =~ /^2..O/) {
            $t_node->set_gram_deontmod('hrt');	
    }

    # gram/sempos 'n.denot' (denominating noun) to the following:
    # first declension lemmas (11A) ending in '-a'
    # second declension lemmas (11B) ending in '-um'
    # third declension lemmas (11C) ending in '-o/-or/-tas'
    # fourth declension lemmas (11D)
    # fifth declension lemmas (11E)
        if (($lex_tag =~ /^11A/ && $lex_lemma =~ /.*a/) || ($lex_tag =~ /^11B/ && $lex_lemma =~ /.*um/) 
        || ($lex_tag =~ /^11C/ && $lex_lemma =~ /.*o/) || ($lex_tag =~ /^11C/ && $lex_lemma =~ /.*or/) 
        || ($lex_tag =~ /^11C/ && $lex_lemma =~ /.*tas/) || ($lex_tag =~ /^11D/) || ($lex_tag =~ /^11E/)) {
            $t_node->set_gram_sempos('n.denot');
    
    }

    # adverbs (i.e. words with 'G' in seventh position of morphological tags) are assigned the 'adv.denot.grad.neg' sempos
        if ($lex_tag =~ /^......G/) {
            $t_node->set_gram_sempos('adv.denot.grad.neg');	
    }

    # sempos 'adj.quant.def'
    # to cardinal and ordinal numerals in the position of syntactic adjectives
    # See 6.2.4 in guidelines for TG annotation
        if (grep $lex_lemma eq $_, qw(unus duo tres quatuor quinque sex septem octo novem decem octoginta
    primus secundus tertius quartus quintus sextus septimus octavus nonus decimus undecimus singulus)) {
            $t_node->set_gram_sempos('adj.quant.def');
    
    }

    # sempos 'adj.quant.indef'
    # to indefinite cardinal and ordinal numerals/adverbs in the position of syntactic adjectives
    # See 6.2.5 in guidelines for TG annotation
        if (grep $lex_lemma eq $_, qw(solus tantus quantus tot quot)) {
            $t_node->set_gram_sempos('adj.quant.indef');
    
    }

    # sempos 'adj.pron.def.demon' to demonstrative pronouns in position of syntactic adjective (iste-ille-hic)
    # NB: demonstrative pronouns can also be nouns ('n.pron.def.demon'):
    # Through this rule, by default they are tagged as adjectives. Manual disambiguation is required
        if (grep $lex_lemma eq $_, qw(idem ipse iste ille hic)) {
            $t_node->set_gram_sempos('adj.pron.def.demon');
    
    }

    # SEIPSE & IS: n.pron.def.demon
        if (grep $lex_lemma eq $_, qw(is seipse)) {
            $t_node->set_gram_sempos('n.pron.def.demon');
    
    }


    # sempos 'n.pron.def.pers' to personal pronouns (ego-tu)
    # and to their possessive counterparts (meus-tuus-suus-vester-noster)
    # including the reflexives (sui).
    # See 6.1.3 in guidelines for TG annotation
        if (grep $lex_lemma eq $_, qw(ego tu meus tuus suus vester noster sui)) {
            $t_node->set_gram_sempos('n.pron.def.pers');
    
    }

    # politeness 'basic' to personal pronouns (ego-tu-is)
    # and to their possessive counterparts (meus-tuus-suus-vester-noster)
    # including the reflexives (sui).
    # See 6.1.3 in guidelines for TG annotation
        if (grep $lex_lemma eq $_, qw(ego tu meus tuus suus vester noster sui)) {
            $t_node->set_gram_politeness('basic');
    
    }

    # person 1 to 'ego' and 'meus'
        if (grep $lex_lemma eq $_, qw(ego meus)) {
            $t_node->set_gram_person('1');	
    }

    # person 2 to 'tu' and 'tuus'
        if (grep $lex_lemma eq $_, qw(tu tuus)) {
            $t_node->set_gram_person('2');	
    }

    # person 3 to 'is' and 'suus'
        if (grep $lex_lemma eq $_, qw(is suus)) {
            $t_node->set_gram_person('3');	
    }

    # person inher to 'sui'
        if ($lex_lemma eq 'sui') {
            $t_node->set_gram_person('inher');	
    }

    # person inher to 'qui'
        if ($lex_lemma eq 'qui') {
            $t_node->set_gram_person('inher');	
    }

    # Degree 'comparative' to all words with tag ^12
    # The degcmp grammateme is assigned to adjectives only, not to nouns. manually check this assignment
        if ($lex_tag =~ /^12/) {
            $t_node->set_gram_degcmp('comp');	
    }

    # Degree 'superlative' to all words with tag ^13
    # The degcmp grammateme is assigned to adjectives only, not to nouns. manually check this assignment
        if ($lex_tag =~ /^13/) {
            $t_node->set_gram_degcmp('sup');	
    }

    # Degree 'positive' to all words with tag ^2....1G
    # These are the positive-degree adverbials derived from participles (like 'consequenter')
        if ($lex_tag =~ /^2....1G/) {
            $t_node->set_gram_degcmp('pos');	
    }

    # Degree 'comparative' to all words with tag ^2....2G
    # These are the comparative adverbials derived from participles (like 'convenientius')
        if ($lex_tag =~ /^2....2G/) {
            $t_node->set_gram_degcmp('comp');	
    }

    # Degree 'superlative' to all words with tag ^2....3G
    # These are the comparative adverbials derived from participles (like 'convenientissime')
        if ($lex_tag =~ /^2....3G/) {
            $t_node->set_gram_degcmp('sup');	
    }

    # sempos 'n.pron.indef' to relative pronouns (qui),
    # to indefinite pronouns (quisquis-quispiam-quisquam-uterque-uterlibet-alteruter-neuter-unusquisque-quisque-aliquis),
    # to interrogative/indefinite pronouns (quis),
    # to negative pronouns (nemo-nihil)
    # all in position of syntactic noun.
    # See 6.1.4 in guidelines for TG annotation
    # NB! these pronouns can also be adjectives ('adj.pron.indef'):	
    # Through this rule, by default they are tagged as nouns. Manual disambiguation is required
        if (grep $lex_lemma eq $_, qw(complures plerusque plurimus qui quisquis quisquam uterque uterlibet alteruter neuter uter utercumque unusquisque quisque aliquis quis nemo nihil)) {
            $t_node->set_gram_sempos('n.pron.indef');
    
    }

    # sempos 'adj.pron.indef'
    # to indefinite pronouns (aliqui-quilibet-quicumque),
    # to negative pronouns (nullus),
    # to totalizing pronouns (alius-alter-reliquus-ceterus-solus-totus-omnis)
    # all in position of syntactic adjective.
    # See 6.3.3 in guidelines for TG annotation
    # NB! these pronouns can also be nouns ('n.pron.indef'):
    # Through this rule, by default they are tagged as adjectives. Manual disambiguation is required
        if (grep $lex_lemma eq $_, qw(aliqui cunctus quilibet quicumque quidam quilibet quispiam quivis nullus ullus universus alius alter reliquus ceterus totus omnis)) {
            $t_node->set_gram_sempos('adj.pron.indef');
    
    }

    # sempos 'n.pron.indef' to 'quidam' as Sb/Obj/Adv
    if ($lex_lemma eq 'quidam' && (grep $lex_afun eq $_, qw(Sb Obj Adv))) {
            $t_node->set_gram_sempos('n.pron.indef');
    
    }

    # person 3 to all n.pron.indef
        if (grep $lex_lemma eq $_, qw(quisquis quispiam quisquam uterque uterlibet alteruter neuter unusquisque quisque aliquis quis nemo)) {
            $t_node->set_gram_person('3');
    
    }

    # person 3 to to 'quidam' as Sb/Obj/Adv
        if ($lex_lemma eq 'quidam' && (grep $lex_afun eq $_, qw(Sb Obj Adv))) {
            $t_node->set_gram_person('3');
    
    }

    # sempos 'adj.pron.indef' to 'quidam' as Atr
    # Not totally safe rule: it can also be the case that quidam/Atr is a noun ('n.pron.indef.)
    if ($lex_lemma eq 'quidam' && $lex_afun eq 'Atr') {
            $t_node->set_gram_sempos('adj.pron.indef');
    
    }

    # sempos 'adv.pron.def' (1)
    # to definite demonstrative and identifying pronominal adverbs, and adverbs derived from these
    # with afun Adv and tag 4-O.*
    # See 6.3.5 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and $lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(hic ibi nunc ibidem tunc ita sic bis exinde hodie))) {
            $t_node->set_gram_sempos('adv.pron.def');
    }

    # sempos 'adv.pron.def' (2)
    # to definite demonstrative and identifying pronominal adverbs, and adverbs derived from these
    # with afun AuxY
    # See 6.3.5 in guidelines for TG annotation
        if ($lex_afun eq 'AuxY' and (grep $lex_lemma eq $_, qw(idcirco propterea postea sic))) {
            $t_node->set_gram_sempos('adv.pron.def');
    }

    # sempos 'adv.pron.def' (3)
    # to definite demonstrative and identifying pronominal adverbs, and adverbs derived from these
    # with afun AuxZ
    # See 6.3.5 in guidelines for TG annotation
        if ($lex_afun eq 'AuxZ' and (grep $lex_lemma eq $_, qw(sic adeo quanto quantum tanto tantum))) {
            $t_node->set_gram_sempos('adv.pron.def');
    }

    # sempos 'adv.pron.def' (4)
    # to definite demonstrative and identifying pronominal adverbs, and adverbs derived from these
    # with afun Adv; forms
    # See 6.3.5 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and (grep $lex_form eq $_, qw(dupliciter hinc illuc qua singillatim singulariter taliter))) {
            $t_node->set_gram_sempos('adv.pron.def');
    }

    # sempos 'adv.pron.def' (5)
    # to definite demonstrative and identifying pronominal adverbs, and adverbs derived from these
    # with tag 4-O.*; lemmas
    # See 6.3.5 in guidelines for TG annotation
        if ($lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(ejusmodi eiusmodi hujusmodi huiusmodi))) {
            $t_node->set_gram_sempos('adv.pron.def');
    }

    # sempos 'adv.pron.indef' (1)
    # to indefinite pronominal adverbs, adverbs derived from these, and some directional/temporal adverbs
    # with afun Adv and tag 4-O.*
    # See 6.3.6 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and $lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(alicubi alibi aliquando quodammodo utrobique aliquoties aliunde nequaquam quotidie quousque ubicumque ubique utcumque))) {
            $t_node->set_gram_sempos('adv.pron.indef');
    }

    # sempos 'adv.pron.indef' (2)
    # to indefinite pronominal adverbs, adverbs derived from these, and some directional/temporal adverbs
    # with afun AuxY
    # See 6.3.6 in guidelines for TG annotation
        if ($lex_afun eq 'AuxY' and (grep $lex_lemma eq $_, qw(quomodo utrum quare quemadmodum numquis usquequaque))) {
            $t_node->set_gram_sempos('adv.pron.indef');
    }

    # sempos 'adv.pron.indef' (3)
    # to indefinite pronominal adverbs, adverbs derived from these, and some directional/temporal adverbs
    # with afun AuxZ
    # See 6.3.6 in guidelines for TG annotation
        if ($lex_afun eq 'AuxZ' and (grep $lex_lemma eq $_, qw(umquam numquam quotiescumque utrobique quantumcumque))) {
            $t_node->set_gram_sempos('adv.pron.indef');
    }

    # sempos 'adv.pron.indef' (4)
    # to specific forms of indefinite pronominal adverbs, adverbs derived from these, and some directional/temporal adverbs
    # See 6.3.6 in guidelines for TG annotation
        if ((grep $lex_form eq $_, qw(aliqualiter aliter cujusmodi cuiusmodi qualiter qualitercumque totaliter))) {
            $t_node->set_gram_sempos('adv.pron.indef');
    }

    # sempos 'adv.denot.ngrad.nneg' (1)
    # to adverbs neither gradable nor can be negated
    # with afun Adv and tag 4-O.*
    # See 6.3.1 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and $lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(interdum semel iterum deinceps deorsum sursum 
                            seorsum postmodum prorsus solummodo utpote ecce forsitan))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.nneg');
    }

    # sempos 'adv.denot.ngrad.nneg' (2)
    # to adverbs neither gradable nor can be negated
    # with afun AuxY
    # See 6.3.1 in guidelines for TG annotation
        if ($lex_afun eq 'AuxY' and (grep $lex_lemma eq $_, qw(quasi immo contra dumtaxat nihilominus scilicet))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.nneg');
    }

    # sempos 'adv.denot.ngrad.nneg' (3)
    # to adverbs neither gradable nor can be negated
    # with afun AuxZ
    # See 6.3.1 in guidelines for TG annotation
        if ($lex_afun eq 'AuxZ' and (grep $lex_lemma eq $_, qw(iam saltem quasi nondum fere forte quamvis quantuscumque))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.nneg');
    }

    # sempos 'adv.denot.ngrad.neg' (1)
    # to adverbs not gradable, but that can be negated
    # with afun Adv and tag 4-O.*
    # See 6.3.2 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and $lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(tanto magis simul bene penitus semper satis subito gratis frustra))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.neg');
    }

    # sempos 'adv.denot.grad.neg'
    # to adverbs gradable that can be negated
    # with afun Adv and tag 4-O.*
    # See 6.3.2 in guidelines for TG annotation
        if ($lex_afun eq 'Adv' and $lex_tag =~ /^4-O/ and (grep $lex_lemma eq $_, qw(bene))) {
            $t_node->set_gram_sempos('adv.denot.grad.neg');
    }

    # sempos 'adv.denot.ngrad.neg' (2)
    # to adverbs not gradable, but that can be negated
    # with afun AuxY
    # See 6.3.2 in guidelines for TG annotation
        if ($lex_afun eq 'AuxY' and (grep $lex_lemma eq $_, qw(statim))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.neg');
    }

    # sempos 'adv.denot.ngrad.neg' (3)
    # to adverbs not gradable, but that can be negated
    # with afun AuxZ
    # See 6.3.2 in guidelines for TG annotation
        if ($lex_afun eq 'AuxZ' and (grep $lex_lemma eq $_, qw(omnino statim quanto quantum tanto tantum tam quam))) {
            $t_node->set_gram_sempos('adv.denot.ngrad.neg');
    }

    # nodetype 'atom' to a number of adverbs (lemmas) (1)
        if ((grep $lex_lemma eq $_, qw(deinde enim ergo ideo igitur nam quidem tamen tunc unde adhuc etiam item non ecce iam forsitan palam o praesertim forsan fortasse alioqui inde itaque item iterum praeterea quinimmo tandem ))) {
            $t_node->set_attr('nodetype', 'atom');
    }

    # nodetype 'atom' to a number of adverbs (forms) (2)
        if ((grep $lex_form eq $_, qw(forte potior vero vere))) {
            $t_node->set_attr('nodetype', 'atom');
    }

    # nodetype 'atom' to 'et' AuxZ (3)
        if ($lex_afun eq 'AuxZ' && $lex_lemma eq 'et') {
            $t_node->set_attr('nodetype', 'atom');
    }

    # the 'atom' nodetype is assigned to nodes with one of the following functors: RHEM PREC ATT CM INTF MOD PARTL
    # NB! This is not a grammateme, but an attribute
        if (grep $functor eq $_, qw(RHEM PREC ATT CM INTF MOD PARTL)) {
            $t_node->set_attr('nodetype', 'atom');
    }

    # indeftype 'relat'
    # to relative pronouns (qui)
        if ($lex_lemma eq 'qui') {
            $t_node->set_gram_indeftype('relat');
    
    }

    # indeftype 'total1'
    # to totalizing pronominal adjectives
        if (grep $lex_lemma eq $_, qw(cunctus solus totus)) {
            $t_node->set_gram_indeftype('total1');
    
    }

    # indeftype 'total2'
    # to totalizing pronominal adjectives
        if (grep $lex_lemma eq $_, qw(omnis universus)) {
            $t_node->set_gram_indeftype('total2');
    
    }

    # indeftype 'indef1'
    # to indefinite pronouns and adverbs
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(alius aliquis aliqui alteruter alicubi alibi aliquando quidam quispiam quisquam quodammodo ullus utrobique)) {
            $t_node->set_gram_indeftype('indef1');
    
    }

    # indeftype 'indef2'
    # to indefinite pronouns and adverbs
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(alter uter utercumque uterlibet uterque)) {
            $t_node->set_gram_indeftype('indef2');
    
    }

    # indeftype 'indef3'
    # to indefinite pronouns and adverbs
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(quicumque quilibet quisquis quivis unusquisque quotiescumque quantumcumque)) {
            $t_node->set_gram_indeftype('indef3');
    
    }

    # indeftype 'indef4'
    # to indefinite pronouns (tantus-quantus-tot-quot)
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(ceterus complures plerusque plurimus reliquus tantus quantus tot quot)) {
            $t_node->set_gram_indeftype('indef4');
    
    }

    # indeftype 'negat'
    # to negative pronouns and adverbs (nemo-nullus-neuter etc.)
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(nemo nullus neuter umquam numquam nihil)) {
            $t_node->set_gram_indeftype('negat');
    
    }

    # indeftype 'inter'
    # to interrogative pronouns and adverbs
    # see 5.6 in TG guidelines
        if (grep $lex_lemma eq $_, qw(quis utrum quomodo quare quemadmodum)) {
            $t_node->set_gram_indeftype('inter');
    
    }

    # '1' on the first and '[ABCDEF]' on the seventh position: number 'singular'
    # The 'number' grammateme is assigned to (semantic) nouns.
    # Since no distinction between adj and nouns is provided in the IT tagset,
    # the 'number' grammateme is in principle assigned to all the nominal and adjectival nodes ('1' on the first position)
        if ($lex_tag =~ /^1.....[ABCDEF]/ && $lex_lemma ne 'qui') {
            $t_node->set_gram_number('sg');	
    }	

    # '1' on the first and '[JKLMNO]' on the seventh position: number 'plural'
    # The 'number' grammateme is assigned to (semantic) nouns.
    # Since no distinction between adj and nouns is provided in the IT tagset,
    # the 'number' grammateme is in principle assigned to all the nominal and adjectival nodes ('1' on the first position)
        if ($lex_tag =~ /^1.....[JKLMNO]/ && $lex_lemma ne 'qui') {
            $t_node->set_gram_number('pl');
    }	

    # if lemma is 'qui', the number is inherited
        if ($lex_lemma eq 'qui') {
            $t_node->set_gram_number('inher');	
    }	

    # if lemma is "vox breviata", the number is 'nr'
        if ($lex_lemma eq "vox breviata") {
            $t_node->set_gram_number('nr');	
    }	

    # if lemma is "vox breviata", the gender is 'nr'
        if ($lex_lemma eq "vox breviata") {
            $t_node->set_gram_gender('nr');	
    }	

    # if lemma is "vox breviata", the sempos is "n.denot"
        if ($lex_lemma eq "vox breviata") {
            $t_node->set_gram_sempos('n.denot');	
    }	

    # if lemma is "num. arab.", the sempos is "adj.quant.def"
        if ($lex_lemma eq "num. arab.") {
            $t_node->set_gram_sempos('adj.quant.def');	
    }	

    # if lemma is "num. arab.", the numertype is 'basic'
        if ($lex_lemma eq "num. arab.") {
            $t_node->set_gram_numertype('basic');	
    }	

    # if the word is a verb (tag ^3), the number is inherited: CANCELLED, because not reported in the guidelines
        #if ($lex_tag =~ /^3/) {
        #    $t_node->set_gram_number('inher');	
    #}	

    # if the gender of the word is 1 (masculine), the gram/gender is 'inan', by default
    # it may be also 'anim'. Manual checking is required.
    # One rule below assigns automatically 'anim' to the most frequent masculine lemmas in the SCG (search for "10 occurrences" and you'll find the rule
        if ($lex_tag =~ /^1......1/ && $lex_lemma ne 'qui') {
            $t_node->set_gram_gender('inan');
    
    }

    # if the gender of the word is 2 (feminine), the gram/gender is 'fem'
        if ($lex_tag =~ /^1......2/ && $lex_lemma ne 'qui') {
            $t_node->set_gram_gender('fem');
    
    }

    # if the gender of the word is 3 (neuter), the gram/gender is 'neut'
        if ($lex_tag =~ /^1......3/ && $lex_lemma ne 'qui') {
            $t_node->set_gram_gender('neut');
    
    }

    # if lemma is 'qui', the gender is inherited
        if ($lex_lemma eq 'qui') {
            $t_node->set_gram_gender('inher');
    
    }

    # if lemma is one of those reported here, the gender is 'anim'
    # these lemmas are chosen since they are the most frequent masculine nouns in the first two books of the SCG (threshold: 10 occurrences)
    if (grep $lex_lemma eq $_, qw(deus homo creatura animal aristoteles philosophus dominus individuus plato artifex angelus sapiens patiens dionysius socrates averroes commentator pater filius puer avicenna alexander discipulus)) {
            $t_node->set_gram_gender('anim');
    
    }	

    # numertype 'basic' (i.e. cardinal) to most frequent cardinal numerals and adj.quant.indef
    if (grep $lex_lemma eq $_, qw(unus duo tres quatuor quinque sex septem octo novem decem octoginta tantus quantus tot quot)) {
            $t_node->set_gram_numertype('basic');
    
    }	

    # numertype 'ord' (i.e. ordinal) to Roman numbers
    if ($lex_lemma eq "num. rom.") {
            $t_node->set_gram_numertype('ord');
    
    }	

    # numertype 'set' to ditributive numbers of the 'singulus' kind
   # if (grep $lex_lemma eq $_, qw(singulus trinus ternus quaternus)) {
    #        $t_node->set_gram_numertype('set');
    
    #}

    # numertype 'kind' to ditributive numbers of the 'bis' and 'duplex' kind
    if (grep $lex_lemma eq $_, qw(semel bis ter quater quinquies sexies septies octies novies decies duplex triplex)) {
            $t_node->set_gram_numertype('kind');
    
    }

    # ordinal numerals have t-lemma identical to the corresponding cardinal number (e.g. 'primus' -> 'unus')
    # NB! The list is not complete (only the most frequent lemmas are reported): for the complete list of ordinal numerals in the IT, see "301-FRLM.DATI"
    # NB! This is not a grammateme, but an attribute

        my %ordinal_numerals = qw/primus unus
                                secundus duo
                                tertius tres
                                quartus quatuor
                                quintus quinque
                                sextus sex
                                septimus septem
                                octavus octo
                                nonus novem
                                decimus decem
                                undecimus undecim
                duodecimus duodecim
                decimussecundus duodecim
                decimustertius tredecim
                tertiusdecimus tredecim
                decimusquartus quatuordecim
                quartusdecimus quatuordecim
                decimusquintus quindecim
                quintusdecimus quindecim
                decimussextus sedecim
                sextusdecimus sedecim
                decimusseptimus septemdecim
                septimusdecimus septemdecim
                duodevicesimus duodeviginti
                decimusoctavus duodeviginti
                octavusdecimus duodeviginti/;
        if (exists $ordinal_numerals{$lex_lemma}) {
            $t_node->set_t_lemma($ordinal_numerals{$lex_lemma});
            $t_node->set_gram_numertype('ord'); # we set the grammateme for ordinal numerals
        }
# numertype 'ord' (i.e. ordinal) to most frequent ordinal numerals
   # "if (grep $lex_lemma eq $_, qw(primus secundus tertius quartus quintus sextus septimus octavus nonus decimus undecimus)) {
    #        $t_node->set_gram_numertype('ord');
    
 #   }

    # distributive numerals have t-lemma identical to the corresponding cardinal number (e.g. 'singulus' -> 'unus')
    # NB! The list is not complete (only the most frequent lemmas are reported): for the complete list of distirbutive numerals in the IT, see "301-FRLM.DATI"
    # NB! This is not a grammateme, but an attribute

        my %distributive_numerals = qw/singulus unus
                                binus duo
                                trinus tres
                                ternus tres
                quaternus quatuor
                                quinus quinque
                                senus sex
                                septenus septem
                                novenus novem
                                denus decem
                duodenus duodecim
                tricenus tredecim
                quaterdenus quatuordecim
                quadragenus quatuordecim
                quinquagenus quindecim
                sexagenus sedecim
                centenus centum/;
        if (exists $distributive_numerals{$lex_lemma}) {
            $t_node->set_attr('t_lemma', $distributive_numerals{$lex_lemma});
	   $t_node->set_gram_numertype('set'); # we set the grammateme for distributive numerals
        }

    # ADV. NUM. MULT. have t-lemma identical to the corresponding cardinal number (e.g. 'semel' -> 'unus')
    # NB! This is not a grammateme, but an attribute

        my %advmult_numerals = qw/semel unus
                                bis duo
                                ter tres
                quater quatuor
                                quinquies quinque
                                sexies sex
                                septies septem
                octies octo
                                novies novem
                                decies decem
                undecies undecim
                duodecies duodecim
                quaterdecies quatuordecim
                vicies viginti
                quadragies quadraginta
                sexagies sexaginta
                septuagies septuaginta
                centies centum
                quadringentesies quadrigenti
                millies mille/;
        if (exists $advmult_numerals{$lex_lemma}) {
            $t_node->set_attr('t_lemma', $advmult_numerals{$lex_lemma});
        }

    # ADJEC. NUM. MULT. have t-lemma identical to the corresponding cardinal number (e.g. 'duplex' -> 'duo')
    # NB! This is not a grammateme, but an attribute

        my %adjmult_numerals = qw/duplex duo
                                triplex tres
                quadruplex quatuor
                                quintuplex quinque
                                septuplex septem/;
        if (exists $adjmult_numerals{$lex_lemma}) {
            $t_node->set_attr('t_lemma', $adjmult_numerals{$lex_lemma});
        }

    # NUM. PROPORT. have t-lemma identical to the corresponding cardinal number (e.g. 'simplus' -> 'unus')
    # NB! This is not a grammateme, but an attribute

        my %proport_numerals = qw/simplus unus
                                duplus duo
                                triplus tres
                quadruplus quatuor
                                quintuplus quinque
                                septuplus septem
                                decuplus decem
                centuplus centum
                quadringentesies quadrigenti
                millies mille/;
        if (exists $proport_numerals{$lex_lemma}) {
            $t_node->set_attr('t_lemma', $proport_numerals{$lex_lemma});
        }

    # Roman numerals have t-lemma identical to the corresponding cardinal number (e.g. 'i' -> 'unus')
    # NB! The list is not complete (only the most frequent lemmas are reported): for the complete list of Roman numerals in the IT, see "301-FRLM.DATI"
    # NB! This is not a grammateme, but an attribute

        my %roman_numerals = qw/i unus
                                ii duo
                                iii tres
                                iv quatuor
                                v quinque
                                vi sex
                                vii septem
                                viii octo
                                ix novem
                                x decem
                                xi undecim
                                xii duodecim
                                xiii tredecim
                                xiv quatuordecim
                                xv quindecim
                                xvi sedecim
                                xvii septemdecim
                                xviii duodeviginti/;
        if ($lex_lemma eq 'num. rom.' and exists $roman_numerals{$lex_form}) {
            $t_node->set_attr('t_lemma', $roman_numerals{$lex_form});
        }

    # Arabic numerals have t-lemma identical to the corresponding cardinal number (e.g. "1" -> 'unus')
    # NB! The list is not complete (only the most frequent lemmas are reported): for the complete list of Arabic numerals in the IT, see "301-FRLM.DATI"
    # NB! This is not a grammateme, but an attribute

        my %arabic_numerals = qw/1 unus
                                2 duo
                                3 tres
                                4 quatuor
                                5 quinque
                                6 sex
                                7 septem
                                8 octo
                                9 novem
                                10 decem
                                11 undecim
                                12 duodecim
                                13 tredecim
                                14 quatuordecim
                                15 quindecim
                                16 sedecim
                                17 septemdecim
                                18 duodeviginti/;
        if ($lex_lemma eq 'num. arab.' and exists $arabic_numerals{$lex_form}) {
            $t_node->set_attr('t_lemma', $arabic_numerals{$lex_form});
        }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::SetGrammatemes - fill grammatemes

=head1 DESCRIPTION

hand-written rules

=head1 AUTHORS

Marco Passarotti

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010,2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
