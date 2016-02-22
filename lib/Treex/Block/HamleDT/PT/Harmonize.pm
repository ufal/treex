package Treex::Block::HamleDT::PT::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToPrague;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'pt::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Phrase-based implementation of tree transformations (21.2.2016).
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->raise_subordinating_conjunctions($root);
    $self->reshape_verb_preposition_infinitive($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://www.linguateca.pt/Floresta/BibliaFlorestal/anexo1.html
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
        my $parent   = $node->parent();
        my $pos      = $node->get_iset('pos');
        my $ppos     = $parent ? $parent->get_iset('pos') : '';
        # Left dependent of adjective or adverb. Typically realized by adverbs.
        # acrescidamente/>A prudentes, tão/>A favoráveis
        if($deprel eq '>A')
        {
            $deprel = 'Adv';
        }
        # Left dependent of noun. Articles, numbers and other determiners.
        # o, a, os, as, um
        elsif($deprel eq '>N')
        {
            $deprel = 'Atr';
        }
        # Left dependent of preposition.
        # At least some examples are emphasizers of prepositional phrases.
        # sobretudo/>P em a colecta
        # particularly in the collection
        # só, ainda, não, apenas, também
        elsif($deprel eq '>P')
        {
            if($node->form() =~ m/^não$/i)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'AuxZ';
            }
        }
        # Left dependent of subordinating conjunction.
        # Typically attached to the predicate of the subordinate clause (instead of to the conjunction)
        # Also note that sometimes there is a relative pronoun or adverb instead of the conjunction.
        # These nodes seem to be an analogy to emphasizers of prepositional phrases.
        # Só quando Pereira lhe surge em a frente
        # Only when Pereira appears in front of you
        # até, só, sobretudo, principalmente
        elsif($deprel eq '>S')
        {
            $deprel = 'AuxZ';
        }
        # Right dependent of adjective or adverb. Prepositional phrases.
        # de, a, em, para, por
        elsif($deprel eq 'A<')
        {
            $deprel = 'Adv';
        }
        # Parenthetical attribute, number.
        # This label is undocumented and occurred only once in the data.
        elsif($deprel eq 'A<PRED')
        {
            $deprel = 'Atr';
        }
        # Accusative, direct object.
        # manter os traços decorativos, querem fugir, encontramos-nos
        # se, que, é, o, está
        elsif($deprel eq 'ACC')
        {
            $deprel = 'Obj';
        }
        # Accusative pronoun that could be also analyzed as passive agent.
        elsif($deprel =~ m/^ACC>?-PASS$/)
        {
            $deprel = 'AuxR';
        }
        # Adverbial modifier. Adverbs, prepositional phrases. Also the negative particle “não”.
        # em, não, para, com, a
        # The ADVO variant is not documented. Adverbial somehow related to an object?
        # The ADVS variant is not documented. Adverbial somehow related to a subject?
        elsif($deprel =~ m/^ADV[LOS]$/)
        {
            if($node->form() =~ m/^não$/i)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Apposition. Typically a noun phrase modifying another noun.
        elsif($deprel eq 'APP')
        {
            $deprel = 'Apposition';
        }
        # Right dependent of subordinating conjunction.
        # Often but not always in comparative expressions. Most frequent parent lemmas: como, que, do_que, conforme, quanto, assim_como.
        elsif($deprel eq 'AS<')
        {
            $deprel = 'SubArg';
        }
        # Auxiliary verb.
        # Auxiliary verbs often head verbal groups and thus their label represents the whole group and is something else than AUX.
        # However, if the group involves a chain of two auxiliaries and one main verb, the middle auxiliary will be labeled AUX.
        # ter sido/AUX suspensa, está a ser/AUX preparado
        # ser, sido, ter, sendo, vir
        elsif($deprel eq 'AUX')
        {
            $deprel = 'AuxV';
        }
        # Right modifier of auxiliary verb.
        # In the few examples I saw, this was the first (head) conjunct of coordinate participles or infinitives, attached to an auxiliary verb.
        # beber, leiloado, eternizar, entregue, apresentada
        elsif($deprel eq 'AUX<')
        {
            $deprel = 'AuxV';
        }
        # Conjunct. Non-first conjunct in coordination is attached to the first conjunct as CJT.
        elsif($deprel eq 'CJT')
        {
            $deprel = 'CoordArg';
        }
        # There are a few (very rare!) examples of coordination of conjuncts with different functions.
        # The first conjunct is labeled PRED, the second is CJT&PRED and the last one is CJT&ADVL.
        ###!!! We cannot currently keep the distinction. Prague solution would be to label the last one as ExD_M.
        elsif($deprel =~ m/^CJT&(PRED|ADVL)$/)
        {
            $deprel = 'CoordArg';
        }
        # Command. Main predicate of a command utterance.
        # Olha/CMD o Carnaval de salão!
        elsif($deprel eq 'CMD')
        {
            $deprel = 'Pred';
        }
        # Coordinating conjunction.
        # It is attached to the first conjunct, regardless between which conjuncts it appears.
        # Punctuation (comma) is also attached to the first conjunct but it is labeled PUNC, not CO.
        # e, mas, ou, nem, como
        elsif($deprel eq 'CO')
        {
            $deprel = 'AuxY';
        }
        # Complementizer in comparative structures.
        # Broken analysis? Normally it should be KOMP<, right? These are leaves and are relatively rare.
        # como, do_que, que, tal_como, conforme
        elsif($deprel eq 'COM')
        {
            $deprel = 'AuxC';
        }
        # Dative (indirect object).
        # Only objects without prepositions, thus pronouns.
        # terá para lhe/DAT dizer
        # will have to tell you
        # lhe, me, lhes, nos, se
        elsif($deprel eq 'DAT')
        {
            $deprel = 'Obj';
        }
        # Exclamation. Main predicate of an exclamative utterance.
        # E bomba!
        elsif($deprel eq 'EXC')
        {
            $deprel = 'Pred';
        }
        # Focus marker.
        # Example: in this case, who wins is the consumer.
        # Same sentence without the focal markers: The consumer wins in this case.
        # quem/FOC sai ganhando é/FOC o consumidor
        # que, é_que, foi, é, era
        elsif($deprel eq 'FOC')
        {
            ###!!! We probably want to reshape the tree here. Nonprojectively, I'm afraid.
            $deprel = 'AuxY';
        }
        # Nucleus.
        # Broken analysis? Normally it should bear the label of the whole noun phrase with respect to its parent.
        # Example: “a dificuldade de...” The three nodes are siblings but they should form one subtree headed by “dificuldade”.
        # Their labels in this wrong structure are >N, H, N<.
        elsif($deprel eq 'H')
        {
            ###!!! The only right thing to do would be to try to reconstruct the correct tree.
            $deprel = 'ExD';
        }
        # Comparative complement. This is the “then” part in “better than me”, attached to “better”.
        # tal ordem, que/SUB só vem/KOMP< a público a verdade oficial
        # such order that only the official truth comes to the public
        # TREE: ordem ( vem/KOMP< ( que/SUB ) )
        # O valor é mais que o dobro de o estimado.
        # The value is more than double the estimate.
        # TREE: é ( valor/SUBJ, mais/SC, que/KOMP< ( dobro/AS< ) )
        # do_que, de, que, como, quanto
        elsif($deprel eq 'KOMP<')
        {
            $deprel = $ppos eq 'verb' ? 'Adv' : 'Atr';
        }
        # Main verb. Infinitive under modal verb, participle under auxiliary “ser” or “ter”.
        # pudessem cair, ser considerada, ter deixado
        # ser, ter, feito, sido, fazer
        elsif($deprel eq 'MV')
        {
            $deprel = 'Obj';
        }
        # Right dependent of noun. Adjectives, prepositional phrases.
        # de, em, para, a, com
        elsif($deprel eq 'N<')
        {
            $deprel = 'Atr';
        }
        # Predicative right modifier of noun.
        # It can be a relative clause but it can also be a noun phrase (we could perceive it as a relative clause with elided copula).
        # Similarly, it can also be a prepositional phrase.
        # de, em, com, é, a
        elsif($deprel eq 'N<PRED')
        {
            $deprel = 'Atr';
        }
        # Dependent of numeral.
        # For example: “X to Y” constructions. Prepositions em, a.
        # 54 a 44
        elsif($deprel eq 'NUM<')
        {
            $deprel = 'Atr';
        }
        # Object complement.
        # Attached to verb but at the same time adding information about the verb's object.
        # Most frequent parent verbs: tornar (render), considerar (consider), ter (have), encontrar (find).
        # encontravam-no enforcado
        # como, em, de, por, impossível
        elsif($deprel eq 'OC')
        {
            $deprel = 'AtvV';
        }
        # Predicator.
        # Lost verb. Examples suggest that in these cases something went wrong with the analysis or its automatic conversion.
        # The verb is sibling of nodes that should be its dependents etc.
        elsif($deprel eq 'P')
        {
            ###!!! The only right thing to do would be to try to reconstruct the correct tree.
            $deprel = 'ExD';
        }
        # Right dependent of preposition. Head noun in prepositional phrase.
        # anos, que, ano, dia, país
        elsif($deprel eq 'P<')
        {
            $deprel = 'PrepArg';
        }
        # Agent in passive construction.
        # Typically a prepositional phrase with preposition “por”.
        # causados por centenas de cães
        # caused by hundreds of dogs
        elsif($deprel eq 'PASS')
        {
            $deprel = 'Obj';
        }
        # Coordinate prepositional phrases.
        # In other treebanks this might be analyzed as two separate prepositional phrases modifying the same verb.
        # However, there is a semantic link between them and this treebank keeps them together.
        # Example: from two to five. Here, “to five” will be attached to “from two” (more precisely it will be attached to “from”) as PCJT.
        # de segunda a quinta
        # TREE: de ( segunda/P<, a/PCJT ( quinta/P< ) )
        elsif($deprel eq 'PCJT')
        {
            ###!!! We will want to reshape the structure so that the first preposition has only one child.
            $deprel = 'Adv';
        }
        # Prepositional object. Prepositional phrases that are arguments of verb, i.e. governed by valency.
        # a, de, em, com, para
        elsif($deprel eq 'PIV')
        {
            $deprel = 'Obj';
        }
        # Main verb coordinate with one of its proper constituents.
        # I found only one example and it was broken. The PMV node “preguntar” was not at all coordinate.
        # It modified a conjunct. But in fact it should be the conjunct and the CJT node here should have be its object.
        elsif($deprel eq 'PMV')
        {
            $deprel = 'Obj';
        }
        # Undocumented and undeciphered tag PRD.
        # This is always the adverb “como” attached to a verb.
        elsif($deprel eq 'PRD')
        {
            $deprel = 'Adv';
        }
        # Predicative adjunct.
        # Loosely attached predicate that provides context to the main predicate.
        # Example: In June, away from the news for months, there was again news.
        # Em Junho, afastada/PRED de os noticiários há meses, era outra vez notícia.
        elsif($deprel eq 'PRED')
        {
            $deprel = 'Adv';
        }
        # Verbal particle.
        # The part of speech of these nodes is often (not always) preposition but they function as conjunctions
        # between auxiliary and main verb. They are attached to the auxiliary as PRT-AUX< and they are leaves.
        # The main verb is their sibling.
        # Variant: PRT-AUX. Here the particle does not lie between the auxiliary and the main verbs because the main verb has been moved.
        # Variant 2: PRT-AUX>. I found only one occurrence and the sentence (not the analysis) was broken.
        # tiveram de/PRT-AUX< esfriar, passou a/PRT-AUX< conversar, tem que/PRT-AUX< ser rápido
        # resistir três vezes quem há de/PRT-AUX?
        # a, de, que, por, para
        elsif($deprel =~ m/^PRT-AUX[<>]?$/)
        {
            $deprel = 'AuxT';
        }
        # Punctuation.
        # , . « » ) (
        elsif($deprel eq 'PUNC')
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
        # Question. Main predicate of an interrogative utterance.
        # Dá/QUE o emprego a o seu amigo?
        elsif($deprel eq 'QUE')
        {
            $deprel = 'Pred';
        }
        # Right addition to utterance. Subordinate clauses.
        elsif($deprel eq 'S<')
        {
            $deprel = 'Adv';
        }
        # Subject complement.
        # This is often what we call nominal predicate with copula. Most frequent parents: é, foi, são, ser, como.
        # O museu está orçado/SC em seis milhões.
        elsif($deprel eq 'SC')
        {
            $deprel = 'Pnom';
        }
        # Statement. Main predicate of a declarative sentence.
        # Verbs. It is not guaranteed that this node's parent is the root.
        # Main predicate of parenthesis is also STA.
        # Coordinate sentences seem to be solved differently from noun coordinations and there are several STA nodes depending on another STA node.
        # é, foi, disse, são, tem
        elsif($deprel eq 'STA')
        {
            $deprel = 'Pred';
        }
        # Subordinating conjunctions are attached to the predicate of their subordinate clause. They are mostly leaves.
        # que, se, porque, embora, já_que
        elsif($deprel eq 'SUB')
        {
            $deprel = 'AuxC';
        }
        # Subject. Nouns and pronouns (including relative pronouns).
        elsif($deprel eq 'SUBJ')
        {
            $deprel = 'Sb';
        }
        # Topic.
        # As esculturas/TOP, ela diz que faz em seis meses.
        # The sculptures, she says she does in six months.
        elsif($deprel eq 'TOP')
        {
            ###!!!
            $deprel = 'ExD';
        }
        # Utterance.
        # Typically non-verb node that governs the whole utterance. This is mostly the only child of the root.
        # Sometimes it occurs deeper in the tree and governs an autonomous subtree. Or it can be one of coordinate utterances.
        elsif($deprel eq 'UTT')
        {
            $deprel = 'ExD';
        }
        # Vocative.
        # VOK: noun phrases used to address people (deputado, gente, governador, mãe, querido).
        # VOC: mostly reflexive pronouns attached to imperative verbs; in a few cases (errors) noun phrases as in VOK.
        elsif($deprel =~ m/^VO[CK]$/)
        {
            $deprel = 'ExD';
        }
        # Unknown function.
        elsif($deprel eq '?')
        {
            if($ppos =~ m/^(noun|num)$/)
            {
                $deprel = 'Atr';
            }
            elsif($ppos =~ m/^(adj|adv|verb)$/)
            {
                $deprel = 'Adv';
            }
            elsif($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            elsif($ppos eq 'conj')
            {
                $deprel = 'SubArg';
            }
            else # part, int, punc, NONE
            {
                $deprel = 'ExD';
            }
        }
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
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
        # o industrial portuense Manuel Macedo, Ramiro Moreira e Pedro Menezes, todos testemunhas em este caso
        # the Porto industrialist Manuel Macedo, Ramiro Moreira and Pedro Menezes, all witnesses in this case
        # Coordination has not been restructured yet, thus the head is the first conjunct ('industrial').
        if(defined($parent) && scalar(@children)==1 &&
           $parent->form() eq 'industrial' &&
           $node->form() eq 'todos' && $node->deprel() eq 'Atr' &&
           $children[0]->form() eq 'testemunhas' && $children[0]->deprel() eq 'Pnom')
        {
            $children[0]->set_parent($parent);
            $children[0]->set_deprel('Apposition');
            $node->set_parent($children[0]);
        }
    }
}



#------------------------------------------------------------------------------
# Reshapes verb-preposition-infinitive constructions such as "tivéssemos de
# informar" ("we had to inform"). In the original treebank the preposition is
# attached to the previous verb as a leaf, labeled "PRT-AUX<", which we
# translate to "AuxT". But we should insert it to the path from the left verb
# to the infinitive, and label it "AuxC" because it functions as a subordinator
# or infinitive marker.
#------------------------------------------------------------------------------
sub reshape_verb_preposition_infinitive
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxT' && $node->is_leaf())
        {
            my $parent = $node->parent();
            my $infinitive = $node->get_right_neighbor();
            if(defined($parent) && $parent->is_verb() &&
               defined($infinitive) && $infinitive->is_infinitive())
            {
                $infinitive->set_parent($node);
                $node->set_deprel('AuxC');
            }
            # Even if the conditions for re-attaching are not met, we do not want
            # to keep the AuxT deprel in Portuguese. Not for prepositions.
            # (Reflexiva tantum might appear in Portuguese but the original treebank
            # does not annotate them.)
            elsif($node->is_adposition() || $node->form() eq 'que')
            {
                $node->set_deprel('AuxC');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::PT::Harmonize

Converts Portuguese trees from CoNLL-X to the HamleDT (Prague) style.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Martin Popel <popel@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
