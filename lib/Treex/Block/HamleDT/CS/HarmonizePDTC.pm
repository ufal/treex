package Treex::Block::HamleDT::CS::HarmonizePDT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::CS::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    # Since PDT-C 1.0 (2021), different Prague Czech treebanks use different, incompatible tagsets.
    default       => 'cs::pdtc',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdtc".'
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
    return $root;
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
    $self->SUPER::fix_morphology($root);
    # In addition to the steps common for Czech Prague-style treebanks, there
    # are some that we have to do for data from ÚFAL but not for FicTree. Do
    # them here.
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Present converbs have one common form (-c/-i) for singular feminines and neuters.
        # Try to disambiguate them based on the tree structure. The method is defined
        # in the SUPER class but it is not called there by default.
        $self->guess_converb_gender($node);
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
        elsif($spanstring =~ m/^je povinna udržovat dům a společná zařízení v dobrém stavu/i)
        {
            my @subtree = $self->get_node_subtree($node);
            # CAC: "je" has the wrong deprel 'AuxP' here.
            $subtree[0]->set_deprel('Pred');
        }
        # PDT-C dev cmpr9417-044-p7s1: wrong case
        elsif($spanstring =~ m/^na vrcholový a střední management a podnikatele$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[4]->set_tag('NNIS4-----A----');
            $subtree[4]->set_conll_pos('NNIS4-----A----');
            $subtree[4]->iset()->set_case('acc');
        }
        # PDT-C dev vesm9211-029-p13s1: wrong case
        elsif($spanstring =~ m/^za socialismu$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_tag('NNIS2-----A----');
            $subtree[1]->set_conll_pos('NNIS2-----A----');
            $subtree[1]->iset()->set_case('gen');
        }
        # PDT-C train-c cmpr9417-032-p12s4: wrong case
        # Teď je tam case=loc. Není to tak jednoznačné. Předložka sice vyžaduje case=ins, ale je-li to gender=neut, mělo by to slovo končit na "-m". Možná to spíš mělo být jedno slovo, "podpaždí".
        elsif($spanstring =~ m/^pod paždí$/)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[1]->set_tag('NNNS7-----A----');
            $subtree[1]->set_conll_pos('NNNS7-----A----');
            $subtree[1]->iset()->set_case('ins');
        }
        # PDT-C test lnd91303-019-p4s3: vernacular "nésó" = "nejsou" (they are not)
        elsif(defined($node->lemma()) && $node->lemma() eq 'nésó')
        {
            $node->set_lemma('být');
            $node->set_tag('VB-P---3P-NAI--');
            $node->set_conll_pos('VB-P---3P-NAI--');
            $node->iset()->set_hash({'pos' => 'verb', 'verbtype' => 'aux', 'aspect' => 'imp', 'mood' => 'ind', 'number' => 'plur', 'person' => '3', 'polarity' => 'neg', 'tense' => 'pres', 'verbform' => 'fin', 'voice' => 'act', 'style' => 'vrnc'});
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::Harmonize

Converts Czech PDT-C (Prague Dependency Treebank Consolidated) analytical trees
to the style of HamleDT (Prague). The two annotation styles are very similar,
thus only minor changes take place. Morphological tags are decoded into Interset.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2014, 2015, 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
