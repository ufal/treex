package Treex::Block::HamleDT::RU::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::MoscowToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ru::syntagrus',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Russian tree, converts morphosyntactic tags to Interset,
# converts dependency relations, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone( $zone );
    # Adjust the tree structure.
    # Phrase-based implementation of tree transformations (7.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::MoscowToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->check_deprels($root);
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
# Convert dependency relation labels.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self = shift;
    my $root = shift;
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
        my $parent = $node->parent();
        my $pos = $node->get_iset('pos');
        my $ppos = $parent->get_iset('pos');
        # The children of the root do not have any dependency relation label in Syntagrus.
        if ($node->parent()->is_root())
        {
            $deprel = $node->get_iset('pos') eq 'verb' ? 'Pred' : 'ExD';
        }
        # 1-компл (1-kompl) is the first complement of a verb.
        # Утрата которая постигла всех нас/1-компл
        # 2-компл (2-kompl) is the second complement of a verb.
        # посвященных законодательству/2-компл (there is no 1-компл, at least not on surface)
        # вернуло нас/1-компл к/2-компл вопросу
        # 3-компл (3-kompl) is the third complement of a verb. It might be even adverbial required by valency.
        # Other complements may or may not be present.
        # сегодня об/3-компл этом даже не пишут
        # 4-компл (4-kompl) is the fourth complement of a verb.
        # снизим налоги/1-компл даже в/4-компл два раза
        # 5-компл (5-kompl) is the fifth complement of a verb.
        # There is only one occurrence in the corpus:
        # кто-то провел по/4-компл векам тончайшей кисточкой/5-компл
        elsif ($deprel =~ m/^[1-5]-компл$/)
        {
            $deprel = 'Obj';
        }
        # 1-несобст-компл (1-nesobst-kompl) is the first improper complement.
        # В/1-несобст-компл тушении пожара приняли участие/1-компл
        # речь идет о/1-несобст-компл средствах
        # 2-несобст-компл (2-nesobst-kompl) is the second improper complement.
        # открыло бы перед/2-несобст-компл молодежью возможность/1-компл
        # 3-несобст-компл (3-nesobst-kompl) is the third improper complement.
        # дать на/3-несобст-компл них исчерпывающие ответы/1-компл
        elsif ($deprel =~ m/^[123]-несобст-компл$/)
        {
            $deprel = 'Obj';
        }
        # авт-аппоз (avt-appoz) seems to be the same kind of apposition as ном-аппоз (see below).
        # There are only two occurrences in the corpus.
        # в работе Сталина Экономические проблемы/авт-аппоз социализма
        elsif ($deprel eq 'авт-аппоз')
        {
            $deprel = 'Atr'; ###!!! Apposition?
        }
        # агент (agent) is a verb argument that is not subject but it is the agent.
        # It can occur e.g. in passive constructions (both reflexive and participial):
        # деятельность детерминируется правилами/агент
        elsif ($deprel eq 'агент')
        {
            $deprel = 'Obj';
        }
        # аддит (addit) is an addition to the amount given by the parent.
        # in “15 час 13 мин 53 сек”, minutes are an addition to hours and seconds are an addition to minutes
        elsif ($deprel eq 'аддит')
        {
            $deprel = 'Atr';
        }
        # адр-присв (adr-prisv) is a dative object with a slightly possessive meaning.
        # There is only one occurrence in the corpus.
        # был президенту/адр-присв как сын
        # he was to the president like a son
        elsif ($deprel eq 'адр-присв')
        {
            $deprel = 'Obj';
        }
        # аналит (analit) is a part of an analytical verb form.
        # It can be the particle "бы" used to form the conditional mood.
        # Скажите если бы/аналит завтра у вас рубль начал...
        # It can also be the infinitive of the content verb, attached to finite form of auxiliary, forming analytical future tense.
        # законопроект ... будет обсуждаться/аналит Думой
        elsif ($deprel eq 'аналит')
        {
            $deprel = 'AuxV';
        }
        # аппоз (appoz) is apposition (second member attached to the first one).
        # Unlike in other treebanks it includes surnames attached to first names.
        elsif ($deprel eq 'аппоз')
        {
            $deprel = 'Apposition';
        }
        # аппрокс-колич (approks-količ) is approximate amount attached to counted noun.
        # It typically occurs after the counted noun.
        elsif ($deprel eq 'аппрокс-колич')
        {
            $deprel = 'Atr';
        }
        # атриб (atrib) may modify a noun phrase or a numerical expression:
        # никто из нас
        # 23 января 2002 года: 23 ( января/атриб ( года/атриб ( 2002/опред ) ) )
        elsif ($deprel eq 'атриб')
        {
            $deprel = 'Atr';
        }
        # вводн (vvodn) is adverbial modifier that specifies meta-conditions, attitude of the speaker etc.
        # наконец
        elsif ($deprel eq 'вводн')
        {
            $deprel = 'Adv';
        }
        # вспом (vspom) ###!!! ???
        # представляет собой/вспом
        # не был да и/вспом не мог быть
        # Ах/вспом да
        elsif ($deprel eq 'вспом')
        {
            $deprel = 'AuxO';
        }
        # дат-субъект (dat-sub"ekt) is the subject that is in dative case, instead of nominative.
        # рабочему надо выточить
        elsif ($deprel eq 'дат-субъект')
        {
            ###!!! We could convert it either to Sb or to Obj.
            ###!!! There are cases where the verb also has a предик child, which we convert to Sb.
            ###!!! Then the verb would have two subjects, which would also be an anomaly.
            ###!!! Cf. to Czech dative in "líbí se mi".
            $deprel = 'Obj';
        }
        # дистанц (distanc) is a unit of distance attached to a number.
        # еще 7 км/дистанц
        # There are only three occurrences in the corpus.
        elsif ($deprel eq 'дистанц')
        {
            $deprel = 'Atr';
        }
        # длительн (dlitel'n) is an adverbial of duration (how long does it take?)
        elsif ($deprel eq 'длительн')
        {
            $deprel = 'Adv';
        }
        # изъясн (iz"jasn) is a clarifying adverbial clause.
        elsif ($deprel eq 'изъясн')
        {
            $deprel = 'Adv';
        }
        # инф-союзн (inf-sojuzn) is an infinitive attached to a subordinating conjunction
        # чтобы дать
        # прежде чем отправить
        elsif ($deprel eq 'инф-союзн')
        {
            $deprel = 'SubArg';
        }
        # квазиагент (kvaziagent) is often a genitive noun modifying another noun
        elsif ($deprel eq 'квазиагент')
        {
            if ($node->parent()->get_iset('pos') =~ m/^(noun|adj|num)$/)
            {
                $deprel = 'Atr';
            }
            else # parent is verb; should the label have been агент instead of квазиагент?
            {
                $deprel = 'Obj';
            }
        }
        # квазиобст (kvaziobst)
        # Very rare, only two occurrences, one: noun modifies noun; the other: adverb modifies verb.
        elsif ($deprel eq 'квазиобст')
        {
            if($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # колич-вспом (količ-vspom) is the dependent part of a multi-word numeral.
        # сорок/колич-вспом пять/количест минут
        elsif ($deprel eq 'колич-вспом')
        {
            $deprel = 'Atr';
        }
        # колич-копред (količ-kopred) means something like co-predicative quantity.
        # It is attached to a verb. It occurs rarely.
        elsif ($deprel eq 'колич-копред')
        {
            ###!!! It is difficult to classify as either Obj, Pnom or Adv according to PDT standards.
            $deprel = 'Adv';
        }
        # колич-огран (količ-ogran) is an adverbial of amount. Its parent may be adjective, adverb, numeral etc.
        # очень интеллигентный
        # хлеба ни полкусочка
        # так легко
        elsif ($deprel eq 'колич-огран')
        {
            if ($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # количест (količest) indicates amount of the thing described by parent.
        elsif ($deprel eq 'количест')
        {
            $deprel = 'Atr';
        }
        # ком-сочин (kom-sočin) is a conjunct with ellipsis (the real conjunct is missing).
        # Эти слова неожиданно были поддержаны и/ком-сочин почти единодушно/соч-союзн
        elsif ($deprel eq 'ком-сочин')
        {
            if ($node->get_iset('pos') eq 'conj')
            {
                $deprel = 'Coord';
                $node->wild()->{coordinator} = 1;
            }
            else
            {
                $deprel = 'CoordArg';
                $node->wild()->{conjunct} = 1;
            }
        }
        # компл-аппоз (kompl-appoz) is usually additional information specifying the parent in an appositional manner (nominative).
        # Крокодила длиной примерно 1 метр/компл-аппоз
        # в возрасте до/компл-аппоз 25 лет
        # пассажирский поезд Санкт-Петербург/компл-аппоз Кисловодск
        elsif ($deprel eq 'компл-аппоз')
        {
            $deprel = 'Atr';
        }
        # композ (kompoz) seems to be the dependent part of compounds.
        # They are joined by a hyphen in text but the hyphen does not have its own node.
        # материально технических
        elsif ($deprel eq 'композ')
        {
            $deprel = 'Atr';
        }
        # композ-аппоз (kompoz-appoz)
        # There is only one occurrence in the corpus.
        # ультразвук с частотами порядка/композ-аппоз 3 МГц
        # ultrasound with frequency 3 MHz
        elsif ($deprel eq 'композ-аппоз')
        {
            $deprel = 'Atr';
        }
        # кратн (kratn) is the second of two numbers denoting an interval (there was a hyphen that is not visible in the tree).
        # семьдесят восемьдесят/кратн
        elsif ($deprel eq 'кратн')
        {
            $deprel = 'Atr';
        }
        # кратно-длительн (kratno-dlitel'n) is a time-expressing noun in plural instrumental.
        # Equivalent of English for-phrases as in "for weeks".
        elsif ($deprel eq 'кратно-длительн')
        {
            $deprel = 'Adv';
        }
        # неакт-компл (neakt-kompl) is a non-active complement, whatever that means. Typically dative.
        # Примеров тому/неакт-компл предостаточно
        elsif ($deprel eq 'неакт-компл')
        {
            $deprel = 'Obj';
        }
        # несобст-агент (nesobst-agent) is improper agent
        # между/несобст-агент жизнью финнов и критян есть и много других различий
        elsif ($deprel eq 'несобст-агент')
        {
            $deprel = 'Adv';
        }
        # ном-аппоз (nom-appoz) is a noun phrase in nominative (regardless the case of the parent) in apposition.
        # In English, one could imagine the word "called" on the dependency link: "in his book [called] Modern Society he claims that..."
        # разрабатывается геоинформационная программа Семипалатинский испытательный ядерный полигон
        # в сборнике Молодые поэты Бурятии
        elsif ($deprel eq 'ном-аппоз')
        {
            $deprel = 'Atr'; ###!!! Apposition?
        }
        # нум-аппоз (num-appoz) is a numerical identification of the parent (e.g. Figure 5)
        # мы получим рисунок 5
        # Формулы 1
        elsif ($deprel eq 'нум-аппоз')
        {
            $deprel = 'Atr'; ###!!! Apposition?
        }
        # об-аппоз (ob-appoz) is apposition.
        # Кевин РАЙЕН военный атташе/об-аппоз посольства США
        elsif ($deprel eq 'об-аппоз')
        {
            $deprel = 'Apposition';
        }
        # об-копр (ob-kopr) is co-predicative object (???)
        # Илья Ильич нашел его в оркестрантской одного
        elsif ($deprel eq 'об-копр')
        {
            $deprel = 'Atv'; ###!!! Obj?
        }
        # об-обст (ob-obst) is object or adverbial (???)
        # There is only one occurrence in the corpus:
        # нестандартные задачи целыми классами/об-обст решаем
        # we solve non-standard tasks keeping the whole class involved
        elsif ($deprel eq 'об-обст')
        {
            $deprel = 'Adv';
        }
        # обст (obst) is adverbial modifier, typically adverb or prepositional phrase.
        elsif ($deprel eq 'обст')
        {
            $deprel = 'Adv';
        }
        # обст-тавт (obst-tavt) is an adverbial modifier expressed by a noun phrase in the instrumental.
        # он один шел своим обычным шагом/обст-тавт
        elsif ($deprel eq 'обст-тавт')
        {
            $deprel = 'Adv';
        }
        # огранич (ogranič) is adverbial modifier indicating scope; includes the negative particle.
        elsif ($deprel eq 'огранич')
        {
            if($node->form() =~ m/^не$/i)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # оп-аппоз (op-appoz) is another subclass of apposition (probably with hyphen, now invisible?)
        # телеведущий Том Брокоу самый высокооплачиваемый тележурналист/оп-аппоз
        elsif ($deprel eq 'оп-аппоз')
        {
            $deprel = 'Apposition';
        }
        # опред (opred) is an adjective modifying a noun.
        # все, этой, этот, эти, всех
        # оп-опред (op-opred) seems to be similar. It involves more often participles and it often occurs after the noun.
        elsif ($deprel =~ m/^(оп-)?опред$/)
        {
            $deprel = 'Atr';
        }
        # пасс-анал (pass-anal) is passive participle attached to finite auxiliary
        # быть поставлен
        elsif ($deprel eq 'пасс-анал')
        {
            $deprel = 'Pnom'; ###!!! V češtině by to sice mohl být Pnom, ale taky trpný rod, ovšem pak by příčestí bylo nahoře a pomocné sloveso by na něm viselo jako AuxV.
        }
        # подч-союзн (podč-sojuzn) is the argument of a subordinating conjunction, i.e. predicate of subordinate clause.
        elsif ($deprel eq 'подч-союзн')
        {
            $deprel = 'SubArg';
        }
        # предик (predik) is subject.
        elsif ($deprel eq 'предик')
        {
            $deprel = 'Sb';
        }
        # предл (predl) is the argument of a preposition, typically a noun.
        elsif ($deprel eq 'предл')
        {
            $deprel = 'PrepArg';
        }
        # презентат (prezentat) is a predicate attached to the particle "вот".
        # Вот немец достает/презентат зажигалку
        elsif ($deprel eq 'презентат')
        {
            $deprel = 'Pred';
        }
        # примыкат (primykat) is adjunct.
        elsif ($deprel eq 'примыкат')
        {
            $deprel = 'Adv';
        }
        # присвяз (prisvjaz) is nominal predicate, often attached to the verb (copula) стать
        elsif ($deprel eq 'присвяз')
        {
            $deprel = 'Pnom';
        }
        # пролепт (prolept) is a noun phrase attached to pronoun ("это") that represents it towards ancestors.
        # Most frequent parents: это, что, вот, так, он; это is by far more frequent than all the others together.
        # Впрочем Homo supersapiens/пролепт это отдаленное будущее
        elsif ($deprel eq 'пролепт')
        {
            $deprel = 'Atr';
        }
        # разъяснит (raz"jasnit) is a phrase that clarifies the term introduced by the parent node.
        # Similar constructions are treated in PDT as apposition because the clarifying phrase describes the same thing, just from a different angle.
        elsif ($deprel eq 'разъяснит')
        {
            $deprel = 'Apposition';
        }
        # распред (raspred) is a distributive specifier (“per capita”, “a day”).
        # в размере двух тысячи рублей на/распред человека
        elsif ($deprel eq 'распред')
        {
            $deprel = 'Atr';
        }
        # релят (reljat) is the predicate of a relative clause.
        elsif ($deprel eq 'релят')
        {
            $deprel = 'Atr';
        }
        # сент-предик (sent-predik) looks like object (???) ###!!!
        # There are only a few occurrences in the corpus.
        elsif ($deprel eq 'сент-предик')
        {
            $deprel = 'Obj';
        }
        # сент-соч (sent-soč) is conjunction or conjunct in coordination of clauses.
        # сочин (sočin) is either coordinating conjunction or (if there is no conjunction) a conjunct attached to previous conjunct.
        elsif ($deprel =~ m/^(сент-соч|сочин)$/)
        {
            if ($node->get_iset('pos') eq 'conj')
            {
                $deprel = 'Coord';
                $node->wild()->{coordinator} = 1;
            }
            else
            {
                $deprel = 'CoordArg';
                $node->wild()->{conjunct} = 1;
            }
        }
        # смещ-атриб (smešč-atrib)
        # Only one occurrence.
        # самого известного у/смещ-атриб нас в стране энтузиаста
        elsif ($deprel eq 'смещ-атриб')
        {
            $deprel = 'Adv';
        }
        # соотнос (sootnos) is a part of a multi-word conjunction.
        # или или
        # как в том так и в другом случае (TREE: в ( том , так и ( как/соотнос , в ( случае ( другом ) ) ) ))
        elsif ($deprel eq 'соотнос')
        {
            $deprel = 'AuxY';
        }
        # соч-союзн (soč-sojuzn) is a conjunct attached to coordinating conjunction (see also сочин).
        elsif ($deprel eq 'соч-союзн')
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }
        # сравн-аппоз (sravn-appoz) is a comparison expressed appositionally.
        # Only one occurrence.
        # Жена его (как/сравн-аппоз и в городе) была прикована к сыну
        elsif ($deprel eq 'сравн-аппоз')
        {
            $deprel = 'Atv';
        }
        # сравн-союзн (sravn-sojuzn) is typically the only child of a comparative subordinator, most frequently "как".
        # See also сравнит, which is a frequent label of the parent.
        elsif ($deprel eq 'сравн-союзн')
        {
            $deprel = 'SubArg';
        }
        # сравнит (sravnit) is the modifier of a comparative that tells to what we are comparing
        # The parent is not necessarily a comparative. It can be a verb and the modifier says "how" the action is done.
        # главнее их/сравнит
        # не позже чем/сравнит
        # спотыкаясь как/сравнит
        elsif ($deprel eq 'сравнит')
        {
            $deprel = 'Adv';
        }
        # суб-копр (sub-kopr)
        # Они все уехали в Москву; TREE: уехали ( Они/predik , все/sub-kopr, в/2-kompl ( Москву ) )
        elsif ($deprel eq 'суб-копр')
        {
            $deprel = 'Atv';
        }
        # суб-обст (sub-obst) is either subject or adverbial.
        # There are only four occurrences in the corpus.
        # студенты группами/суб-обст 8 12 человек ... работают
        elsif ($deprel eq 'суб-обст')
        {
            $deprel = 'Adv';
        }
        # уточн (utočn) adds precision to the information expressed by the parent.
        # у нас на Украине; TREE: у ( нас , на/уточн ( Украине ) )
        elsif ($deprel eq 'уточн')
        {
            $deprel = 'Adv';
        }
        # эксплет (èksplet) is the explicative part of patterns так-как, то-что, attached to the demonstrative pronoun
        elsif ($deprel eq 'эксплет')
        {
            $deprel = 'Atr'; ###!!! but some of the demonstratives are adverbs; should we assign Adv then?
        }
        # электив (èlektiv) denotes the set from which the governing node was taken.
        # Very often expressed using the preposition из (from, of).
        # один из/электив гостей
        elsif ($deprel eq 'электив')
        {
            $deprel = 'Atr';
        }
        # эллипт (èllipt) appears where ellipsis is involved.
        # Two or more real sentences in one tree, a verbless phrase as sentence etc.
        elsif ($deprel eq 'эллипт')
        {
            $deprel = 'ExD';
        }
        # punct is a deprel that we introduce on reading Syntagrus, when creating nodes for punctuation.
        elsif ($deprel eq 'punct')
        {
            my $form = $node->form() // '';
            if($form eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        else
        {
            log_warn("Unknown dependency relation '$deprel'");
            ###!!!$node->set_deprel('Atr');
        }
        $node->set_deprel($deprel);
    }
}



1;

=over

=item Treex::Block::HamleDT::RU::Harmonize

Converts Syntagrus (Russian Dependency Treebank) trees to the style of HamleDT (Prague).
Morphological tags will be decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
# Copyright 2011 David Mareček <marecek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
