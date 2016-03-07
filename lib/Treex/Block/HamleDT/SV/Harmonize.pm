package Treex::Block::HamleDT::SV::Harmonize;
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
    default       => 'sv::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Swedish tree, converts morphosyntactic tags to Interset,
# converts dependency relations, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    # Phrase-based implementation of tree transformations (7.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::MoscowToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://stp.ling.uu.se/~nivre/research/Talbanken05.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # The corpus contains the following 64 dependency relation tags:
        # ++ +A +F AA AG AN AT BS C+ CA CC CJ DB DT EF EO ES ET FO FS FV HD I?
        # IC IG IK IM IO IP IQ IR IS IT IU IV JC JG JR JT KA MA MD MS NA OA OO
        # PA PL PT RA ROOT  SP SS ST TA UK VA VG VO VS XA XF XT XX
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $ppos   = $parent->get_iset('pos');

        # Dependency of the main verb on the artificial root node.
        if ( $deprel eq 'ROOT' )
        {
            if ( $pos eq 'verb' )
            {
                $deprel = 'Pred';
            }
            else
            {
                $deprel = 'ExD';
            }
        }

        # Coordinating conjunction
        elsif ( $deprel eq '++' )
        {
            if($parent->conll_deprel() =~ m/^(CC|C\+|CJ|\+F|MS)$/)
            {
                $deprel = 'Coord';
                $node->wild()->{coordinator} = 1;
            }
            # Occasionally the coordinating conjunction may not have strictly coordinating function.
            # Example (train/002.treex#185):
            # nygifta, och speciellt då nygifta med småbarn
            # newly married, and especially when newly married with small children
            # Here, 'och' is attached to the second 'nygifta', which is an apposition of the first 'nygifta'.
            # Deprel tags are as follows:
            # SS IK ++ CA TA AN ET PA
            else
            {
                $deprel = 'AuxY';
            }
        }

        # Conjunctional adverbial
        elsif ( $deprel eq '+A' )
        {
            $deprel = 'Adv';
        }

        # Coordination at main clause level
        elsif ( $deprel eq '+F' )
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Other adverbial
        elsif ( $deprel eq 'AA' )
        {
            $deprel = 'Adv';
        }

        # Agent
        elsif ( $deprel eq 'AG' )
        {
            # DZ: Used e.g. in the following sentence (train/001.treex#17):
            # I många familjer finns diktatur, där uppfostras barnen till goda medborgare av föräldrarna på deras eget lilla vis.
            # Google Translate:
            # In many families there is dictatorship, which brought the children into good citizens of the parents in their own little way.
            # The phrase 'av föräldrarna' ('of the parents') is tagged 'AG'.
            # After consultation with Silvie:
            # The '-s' suffix of 'uppfostras' puts the verb into mediopassive. So the literal translation could be closer to:
            # In many families there is dictatorship, where brought-are children into good citizens by the parents in their own little way.
            # So from the point of view of the analytical layer of the PDT, we can say that the parents are Obj
            # (while on the tectogrammatical layer they are the Actor).
            $deprel = 'Obj';
        }

        # Apposition
        elsif ( $deprel eq 'AN' )
        {
            # DZ: example (train/001.treex#10):
            # flera problem t.+ex. pliktkänslan
            # several problems, for example sense of duty
            # Original tree: problem/OO ( flera/DT, pliktkänslan/AN ( t.+ex./CA ) )
            # PDT style:     t.+ex./Apos ( problem/Obj_Ap ( flera/Atr ), pliktkänslan/Obj_Ap )
            $deprel = 'Apposition';
        }

        # Nominal (adjectival) pre-modifier
        elsif ( $deprel eq 'AT' )
        {
            $deprel = 'Atr';
        }

        # Subordinate clause minus subordinating conjunction
        elsif ( $deprel eq 'BS' )
        {
            $deprel = 'Adv';
        }

        # Second conjunct (sister of conjunction) in binary branching analysis
        elsif ( $deprel eq 'C+' )
        {
            # train/001.treex#120 ('hjälpsamhet' = 'helpfulness')
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Contrastive adverbial
        elsif ( $deprel eq 'CA' )
        {
            $deprel = 'Adv';
        }

        # Sister of first conjunct in binary branching analysis of coordination
        # DZ: This is the prevailing tag for non-first coordination members.
        elsif ( $deprel eq 'CC' )
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Conjunct
        # First conjunct in binary branching analysis of coordination
        elsif ( $deprel eq 'CJ' )
        {
            # DZ: example (train/001.treex#387): standardkraven/CJ (attached to 'Stressen'); CC: trångboddheten, pressen, miljön
            # Stressen standardkraven, trångboddheten, den ekonomiska pressen och miljön skapar svårigheter för en familj.
            # Stress of the standard requirements, overcrowding, the financial press and the environment creates difficulties for a family.
            ###!!! The example is strange and I still don't understand it fully. The above translation is from Google so I may be missing something.
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Doubled function
        elsif ( $deprel eq 'DB' )
        {
            # DZ: example (train/001.treex#51):
            # Om inte samtliga individer är av samma uppfattning, som debattörerna, så är individen ifråga genast: oförstående för sitt eget bästa.
            # If not all individuals are of the same opinion, as debaters, so is the individual in question immediately: incomprehension for his own good.
            # Analogous Czech PDT tree:
            #     jestliže dal, pak schválí
            #     schválí/??? ( jestliže/AuxC ( dal/Adv, ,/AuxX ), pak/Adv )
            # Desired PDT-style tree for the example:
            #     är/??? ( Om/AuxC ( är/Adv, ,/AuxX ), så/Adv )
            # Original Swedish tree for the example: 'så' attached non-projectively with 'doubled function' 'DB':
            #     är/??? ( är/AA ( Om/UK, så/DB ), ,/IK )
            ###!!!
            $deprel = 'Adv';
        }

        # Determiner
        elsif ( $deprel eq 'DT' )
        {
            # 'AuxA' is not a known value in PDT. It is used in Treex for English articles 'a', 'an', 'the'.
            # Other determiners ('this', 'each', 'any'...) are usually tagged 'Atr'.
            # We use 'Atr' here because the 'DT' tag is used for general determiners, not just articles.
            $deprel = 'Atr';
        }

        # Relative clause in cleft ("trhlina, štěrbina")
        elsif ( $deprel eq 'EF' )
        {
            ###!!!
            # DZ: The first example of this tag (train/001.treex#29) is strange.
            # I would not attach it to 'vad'. I believe it is coordinated with the main clause ('vi kan...')
            # We should look at more examples before deciding.
            $deprel = 'ExD';
        }

        # Logical object
        elsif ( $deprel eq 'EO' )
        {
            # DZ: example (train/001.treex#176):
            # får det enklare att klara/EO av att leva
            # get it easier to manage/EO to live
            $deprel = 'Obj';
        }

        # Logical subject
        elsif ( $deprel eq 'ES' )
        {
            # DZ: example (train/001.treex#10):
            # det kommer några andra
            # it comes no other (~ there is no other)
            $deprel = 'Atv'; ###!!! not sure whether this is the closest match?
        }

        # Other nominal post-modifier
        elsif ( $deprel eq 'ET' )
        {
            $deprel = 'Atr';
        }

        # Dummy object
        elsif ( $deprel eq 'FO' )
        {
            $deprel = 'Obj';
        }

        # Dummy subject
        elsif ( $deprel eq 'FS' )
        {
            $deprel = 'Sb';
        }

        # Finite predicate verb
        elsif ( $deprel eq 'FV' )
        {
            # DZ: the example sentence (train/001.treex#172) currently gets restructured badly ('definitivt').
            # But the original is bad, too.
            # Anyway, in this particular sentence 'FV' is the main verb of an adverbial ('if'-) clause.
            $deprel = 'Adv';
        }

        # Other head
        elsif ( $deprel eq 'HD' )
        {
            # train/001.treex#4 ('sedan')
            $deprel = 'Adv';
        }

        # Question mark
        elsif ( $deprel eq 'I?' )
        {
            ###!!! DZ: I have not checked whether 'I?' occurs elsewhere than at the end of the sentence.
            $deprel = 'AuxK';
        }

        # Quotation mark
        elsif ( $deprel eq 'IC' )
        {
            $deprel = 'AuxG';
        }

        # Part of idiom (multi-word unit)
        elsif ( $deprel eq 'ID' )
        {
            # DZ: This tag does not occur in the treebank but it appears in the documentation.
            # Note that there is a POS tag 'ID' with the same meaning (example 001#7: the s-tag is 'HD' in this case).
        }

        # Infinitive phrase minus infinitive marker
        elsif ( $deprel eq 'IF' )
        {
            # DZ: This tag does not occur in the treebank.
        }

        # Other punctuation mark
        elsif ( $deprel eq 'IG' )
        {
            $deprel = 'AuxG';
        }

        # Comma
        elsif ( $deprel eq 'IK' )
        {
            $deprel = 'AuxX';
        }

        # Infinitive marker
        elsif ( $deprel eq 'IM' )
        {
            $deprel = 'AuxV'; ###!!! converted to AuxC in some other languages; it is not a verb form, so what?
        }

        # Indirect object
        elsif ( $deprel eq 'IO' )
        {
            $deprel = 'Obj';
        }

        # Period
        elsif ( $deprel eq 'IP' )
        {
            $deprel = 'AuxK'; # approx.
        }

        # Colon
        elsif ( $deprel eq 'IQ' )
        {
            $deprel = 'AuxG';
        }

        # Parenthesis
        elsif ( $deprel eq 'IR' )
        {
            $deprel = 'AuxG';
        }

        # Semicolon
        elsif ( $deprel eq 'IS' )
        {
            # DZ: Sentences in PDT are frequently split on semicolons, which are then tagged 'AuxK'.
            # Sometimes they are also tagged 'ExD_Pa'.
            # Otherwise a sentence-internal semicolon is tagged 'AuxG'.
            $deprel = 'AuxG';
        }

        # Dash
        elsif ( $deprel eq 'IT' )
        {
            $deprel = 'AuxG';
        }

        # Exclamation mark
        elsif ( $deprel eq 'IU' )
        {
            $deprel = 'AuxK';
        }

        # Nonfinite verb
        elsif ( $deprel eq 'IV' )
        {
            # DZ: example (train/001.treex#31): 'kunna':
            # Det skulle betyda att jag skulle kunna älska en partner som utförde mobbing på mig varje dag.
            # That would mean that I could love a partner who did bullying at me every day.
            $deprel = 'AuxV';
        }

        # Second quotation mark
        elsif ( $deprel eq 'JC' )
        {
            $deprel = 'AuxG';
        }

        # Second (other) punctuation mark
        elsif ( $deprel eq 'JG' )
        {
            # DZ: example (train/009.treex#129):
            # 'Man och hustru äro skyldiga ...' är inledningsorden i femte kapitlet giftermålsbalken, och forsätter: '... varandra
            # The first '...' is tagged 'IG', the second '...' is tagged 'JG'.
            $deprel = 'AuxG';
        }

        # Second parenthesis
        elsif ( $deprel eq 'JR' )
        {
            $deprel = 'AuxG';
        }

        # Second dash
        elsif ( $deprel eq 'JT' )
        {
            $deprel = 'AuxG';
        }

        # Comparative adverbial
        elsif ( $deprel eq 'KA' )
        {
            $deprel = 'Adv';
        }

        # Attitude adverbial
        elsif ( $deprel eq 'MA' )
        {
            $deprel = 'Adv';
        }

        # Undocumented tag 'MD'. 'Modifier'?
        # Example (train/001.treex#26): subtree "den ena, eller båda" is tagged 'MD'.
        elsif ( $deprel eq 'MD' )
        {
            $deprel = 'Atr';
        }

        # Macrosyntagm
        elsif ( $deprel eq 'MS' )
        {
            # DZ: example (train/001.treex#10) 'kommer' in:
            # Detta löser problem men det kommer några andra
            # This solves the problem but there is no other
            # Original tree: löser/ROOT ( kommer/MS ( men/++ ) )
            # PDT style:     men/Coord ( löser/Pred_Co, kommer/Pred_Co )
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Negation adverbial
        elsif ( $deprel eq 'NA' )
        {
            $deprel = 'Adv';
        }

        # Object adverbial
        elsif ( $deprel eq 'OA' )
        {
            $deprel = 'Adv';
        }

        # Other object
        elsif ( $deprel eq 'OO' )
        {
            $deprel = 'Obj';
        }

        # Complement of preposition
        elsif ( $deprel eq 'PA' )
        {
            $deprel = 'PrepArg';
        }

        # Verb particle
        elsif ( $deprel eq 'PL' )
        {
            $deprel = 'AuxV';
        }

        # Preposition
        elsif ( $deprel eq 'PR' )
        {
            $deprel = 'AuxP';
        }

        # Predicative attribute
        elsif ( $deprel eq 'PT' )
        {
            # DZ: example (train/001.treex#61): 'själv':
            # än sig själv
            # than itself
            $deprel = 'Atr';
        }

        # Place adverbial
        elsif ( $deprel eq 'RA' )
        {
            $deprel = 'Adv';
        }

        # Subjective predicative complement
        elsif ( $deprel eq 'SP' )
        {
            $deprel = 'Atv';
        }

        # Other subject
        elsif ( $deprel eq 'SS' )
        {
            $deprel = 'Sb';
        }

        # Paragraph
        elsif ( $deprel eq 'ST' )
        {
            ###!!! ??? (train/001.treex#320: 'institution')
            $deprel = 'ExD';
        }

        # Time adverbial
        elsif ( $deprel eq 'TA' )
        {
            $deprel = 'Adv';
        }

        # Subordinating conjunction
        elsif ( $deprel eq 'UK' )
        {
            $deprel = 'AuxC';
        }

        # Varslande adverbial
        elsif ( $deprel eq 'VA' )
        {
            $deprel = 'Adv';
        }

        # Verb group
        elsif ( $deprel eq 'VG' )
        {
            $deprel = 'Atv';
        }

        # Infinitive object complement
        elsif ( $deprel eq 'VO' )
        {
            # vara/VO (train/001.treex#43):
            # I vissa fall anser man förtjänsten vara värd en omsvängning i attityden.
            # In some cases one considers the earnings to be worth a shift in attitude.
            $deprel = 'Obj';
        }

        # Infinitive subject complement
        elsif ( $deprel eq 'VS' )
        {
            # vara/VS (train/001.treex#406):
            # familjen sägs i artikeln vara en social institution
            # family is said in the article to be a social institution
            $deprel = 'Obj';
        }

        # Expressions like "så att säga" (so to speak)
        elsif ( $deprel eq 'XA' )
        {
            # DZ: found in PDT 'takřka' tagged 'AuxZ'; found 'tak říkajíc' tagged 'Adv'
            $deprel = 'AuxZ';
        }

        # Fundament phrase
        elsif ( $deprel eq 'XF' )
        {
            # 'från' (train/004.treex#64):
            # Fr&#229n denna fria värld
            # From this free world
            # HV: Can have virtually any grammatical function, hard to guess (maybe heuristics from tag?)
            if ( $ppos eq 'verb' )
            {
                $deprel = 'Adv';
            }
            else
            {
                $deprel = 'Atr';
            }
        }

        # Expressions like "så kallad" (so called)
        elsif ( $deprel eq 'XT' )
        {
            $deprel = 'Atr'; # as 'tzv' in PDT
        }

        # Unclassifiable grammatical function
        elsif ( $deprel eq 'XX' )
        {
            # HV: should this really be an ellipsis?
            $deprel = 'ExD';
        }

        # Interjection phrase
        elsif ( $deprel eq 'YY' )
        {
            # DZ: This tag has not occurred in the treebank.
        }

        $node->set_deprel($deprel);
        if ( $node->wild()->{conjunct} && $node->wild()->{coordinator} )
        {
            log_warn('We do not expect a node to be conjunct and coordination at the same time.');
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Swedish
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_moscow($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_orphans();
    push(@recurse, $coordination->get_children());
    return @recurse;
}

1;

=over

=item Treex::Block::HamleDT::SV::Harmonize

Converts trees coming from the Swedish Mamba Treebank via the CoNLL-X format to the style of
HamleDT (Prague). Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
