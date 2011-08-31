package Treex::Block::A2A::SV::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Swedish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
    #$self->lift_noun_phrases($a_root);
    $self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    #$self->check_afuns($a_root);
    $self->deprel_to_afun($a_root); # must follow coord. restructuring, probably executed twice now
}


my %pos2afun = (
    prep => 'AuxP',
);


#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://stp.ling.uu.se/~nivre/research/Talbanken05.html
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {

        # The corpus contains the following 64 dependency relation tags:
        # ++ +A +F AA AG AN AT BS C+ CA CC CJ DB DT EF EO ES ET FO FS FV HD I?
        # IC IG IK IM IO IP IQ IR IS IT IU IV JC JG JR JT KA MA MD MS NA OA OO
        # PA PL PT RA ROOT  SP SS ST TA UK VA VG VO VS XA XF XT XX
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $ppos   = $parent->get_iset('pos');
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ( $deprel eq 'ROOT' )
        {
            if ( $pos eq 'verb' )
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }

        # Coordinating conjunction
        elsif ( $deprel eq '++' )
        {
            $afun = 'Coord';
        }

        # Conjunctional adverbial
        elsif ( $deprel eq '+A' )
        {
            $afun = 'Adv';
        }

        # Coordination at main clause level
        elsif ( $deprel eq '+F' )
        {
            # DZ: the temporary afun 'CoordArg' would fit here but Zdeněk's processing does not use it
        }

        # Other adverbial
        elsif ( $deprel eq 'AA' )
        {
            $afun = 'Adv';
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
            $afun = 'Obj';
        }

        # Apposition
        elsif ( $deprel eq 'AN' )
        {
            # DZ: example (train/001.treex#10):
            # flera problem t.+ex. pliktkänslan
            # several problems, for example sense of duty
            # Original tree: problem/OO ( flera/DT, pliktkänslan/AN ( t.+ex./CA ) )
            # PDT style:     t.+ex./Apos ( problem/Obj_Ap ( flera/Atr ), pliktkänslan/Obj_Ap )
            ###!!! Use the temporary afun CoordArg?
        }

        # Nominal (adjectival) pre-modifier
        elsif ( $deprel eq 'AT' )
        {
            $afun = 'Atr';
        }

        # Contrastive adverbial
        elsif ( $deprel eq 'CA' )
        {
            $afun = 'Adv';
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
        }

        # Determiner
        elsif ( $deprel eq 'DT' )
        {
            # 'AuxA' is not a known value in PDT. It is used in Treex for English articles 'a', 'an', 'the'.
            # Other determiners ('this', 'each', 'any'...) are usually tagged 'Atr'.
            $afun = 'AuxA';
        }

        # Relative clause in cleft ("trhlina, štěrbina")
        elsif ( $deprel eq 'EF' )
        {
            ###!!!
            # DZ: The first example of this tag (train/001.treex#29) is strange.
            # I would not attach it to 'vad'. I believe it is coordinated with the main clause ('vi kan...')
            # We should look at more examples before deciding.
        }

        # Logical object
        elsif ( $deprel eq 'EO' )
        {
            # DZ: example (train/001.treex#176):
            # får det enklare att klara/EO av att leva
            # get it easier to manage/EO to live
            $afun = 'Obj';
        }

        # Logical subject
        elsif ( $deprel eq 'ES' )
        {
            # DZ: example (train/001.treex#10):
            # det kommer några andra
            # it comes no other (~ there is no other)
            $afun = 'Atv'; ###!!! not sure whether this is the closest match?
        }

        # Other nominal post-modifier
        elsif ( $deprel eq 'ET' )
        {
            $afun = 'Atr';
        }

        # Dummy object
        elsif ( $deprel eq 'FO' )
        {
            $afun = 'Obj';
        }

        # Dummy subject
        elsif ( $deprel eq 'FS' )
        {
            $afun = 'Sb';
        }

        # Finite predicate verb
        elsif ( $deprel eq 'FV' )
        {
            # DZ: the example sentence (train/001.treex#172) currently gets restructured badly ('definitivt').
            # But the original is bad, too.
            # Anyway, in this particular sentence 'FV' is the main verb of an adverbial ('if'-) clause.
            $afun = 'Adv';
        }

        # Question mark
        elsif ( $deprel eq 'I?' )
        {
            ###!!! DZ: I have not checked whether 'I?' occurs elsewhere than at the end of the sentence.
            $afun = 'AuxK';
        }

        # Quotation mark
        elsif ( $deprel eq 'IC' )
        {
            $afun = 'AuxG';
        }

        # Part of idiom (multi-word unit)
        elsif ( $deprel eq 'ID' )
        {
            # DZ: This tag does not occur in the treebank but it appears in the documentation.
            # Note that there is a POS tag 'ID' with the same meaning (example 001#7: the s-tag is 'HD' in this case).
        }

        # Other punctuation mark
        elsif ( $deprel eq 'IG' )
        {
            $afun = 'AuxG';
        }

        # Comma
        elsif ( $deprel eq 'IK' )
        {
            $afun = 'AuxX';
        }

        # Infinitive marker
        elsif ( $deprel eq 'IM' )
        {
            $afun = 'AuxV'; ###!!! converted to AuxC in some other languages; it is not a verb form, so what?
        }

        # Indirect object
        elsif ( $deprel eq 'IO' )
        {
            $afun = 'Obj';
        }

        # Period
        elsif ( $deprel eq 'IP' )
        {
            $afun = 'AuxK'; # approx.
        }

        # Colon
        elsif ( $deprel eq 'IQ' )
        {
            $afun = 'AuxG';
        }

        # Parenthesis
        elsif ( $deprel eq 'IR' )
        {
            $afun = 'AuxG';
        }

        # Semicolon
        elsif ( $deprel eq 'IS' )
        {
            # DZ: Sentences in PDT are frequently split on semicolons, which are then tagged 'AuxK'.
            # Sometimes they are also tagged 'ExD_Pa'.
            # Otherwise a sentence-internal semicolon is tagged 'AuxG'.
            $afun = 'AuxG';
        }

        # Dash
        elsif ( $deprel eq 'IT' )
        {
            $afun = 'AuxG';
        }

        # Exclamation mark
        elsif ( $deprel eq 'IU' )
        {
            $afun = 'AuxK';
        }

        # Nonfinite verb
        elsif ( $deprel eq 'IV' )
        {
            # DZ: example (train/001.treex#31): 'kunna':
            # Det skulle betyda att jag skulle kunna älska en partner som utförde mobbing på mig varje dag.
            # That would mean that I could love a partner who did bullying at me every day.
            $afun = 'AuxV';
        }

        # Second quotation mark
        elsif ( $deprel eq 'JC' )
        {
            $afun = 'AuxG';
        }

        # Second (other) punctuation mark
        elsif ( $deprel eq 'JG' )
        {
            # DZ: example (train/009.treex#129):
            # 'Man och hustru äro skyldiga ...' är inledningsorden i femte kapitlet giftermålsbalken, och forsätter: '... varandra
            # The first '...' is tagged 'IG', the second '...' is tagged 'JG'.
            $afun = 'AuxG';
        }

        # Second parenthesis
        elsif ( $deprel eq 'JR' )
        {
            $afun = 'AuxG';
        }

        # Second dash
        elsif ( $deprel eq 'JT' )
        {
            $afun = 'AuxG';
        }

        # Comparative adverbial
        elsif ( $deprel eq 'KA' )
        {
            $afun = 'Adv';
        }

        # Attitude adverbial
        elsif ( $deprel eq 'MA' )
        {
            $afun = 'Adv';
        }

        # Macrosyntagm
        elsif ( $deprel eq 'MS' )
        {
            # DZ: example (train/001.treex#10) 'kommer' in:
            # Detta löser problem men det kommer några andra
            # This solves the problem but there is no other
            # Original tree: löser/ROOT ( kommer/MS ( men/++ ) )
            # PDT style:     men/Coord ( löser/Pred_Co, kommer/Pred_Co )
            $afun = 'Pred';
        }

        # Negation adverbial
        elsif ( $deprel eq 'NA' )
        {
            $afun = 'Adv';
        }

        # Object adverbial
        elsif ( $deprel eq 'OA' )
        {
            $afun = 'Adv';
        }

        # Other object
        elsif ( $deprel eq 'OO' )
        {
            $afun = 'Obj';
        }

        # Verb particle
        elsif ( $deprel eq 'PL' )
        {
            $afun = 'AuxV';
        }

        # Preposition
        elsif ( $deprel eq 'PR' )
        {
            $afun = 'AuxP';
        }

        # Predicative attribute
        elsif ( $deprel eq 'PT' )
        {
            # DZ: example (train/001.treex#61): 'själv':
            # än sig själv
            # than itself
            $afun = 'Atr';
        }

        # Place adverbial
        elsif ( $deprel eq 'RA' )
        {
            $afun = 'Adv';
        }

        # Subjective predicative complement
        elsif ( $deprel eq 'SP' )
        {
            $afun = 'Atv';
        }

        # Other subject
        elsif ( $deprel eq 'SS' )
        {
            $afun = 'Sb';
        }

        # Paragraph
        elsif ( $deprel eq 'ST' )
        {
            ###!!! ??? (train/001.treex#320: 'institution')
            $afun = 'ExD';
        }

        # Time adverbial
        elsif ( $deprel eq 'TA' )
        {
            $afun = 'Adv';
        }

        # Subordinating conjunction
        elsif ( $deprel eq 'UK' )
        {
            $afun = 'AuxC';
        }

        # Varslande adverbial
        elsif ( $deprel eq 'VA' )
        {
            $afun = 'Adv';
        }

        # Infinitive object complement
        elsif ( $deprel eq 'VO' )
        {
            # vara/VO (train/001.treex#43):
            # I vissa fall anser man förtjänsten vara värd en omsvängning i attityden.
            # In some cases one considers the earnings to be worth a shift in attitude.
            $afun = 'Obj';
        }

        # Infinitive subject complement
        elsif ( $deprel eq 'VS' )
        {
            # vara/VS (train/001.treex#406):
            # familjen sägs i artikeln vara en social institution
            # family is said in the article to be a social institution
            $afun = 'Obj';
        }

        # Expressions like "så att säga" (so to speak)
        elsif ( $deprel eq 'XA' )
        {
            # DZ: found in PDT 'takřka' tagged 'AuxZ'; found 'tak říkajíc' tagged 'Adv'
            $afun = 'AuxZ';
        }

        # Fundament phrase
        elsif ( $deprel eq 'XF' )
        {
            # 'från' (train/004.treex#64):
            # Fr&#229n denna fria värld
            # From this free world
            # DZ: anyway this particular node ended up tagged correctly as 'AuxP' governing an 'Adv', so do nothing.
        }

        # Expressions like "så kallad" (so called)
        elsif ( $deprel eq 'XT' )
        {
            $afun = 'Atr'; # as 'tzv' in PDT
        }

        # Unclassifiable grammatical function
        elsif ( $deprel eq 'XX' )
        {
            $afun = 'ExD';
        }

        # Interjection phrase
        elsif ( $deprel eq 'YY' )
        {
            # DZ: This tag has not occurred in the treebank.
        }

        # Conjunct
        # First conjunct in binary branching analysis of coordination
        elsif ( $deprel eq 'CJ' )
        {
            # DZ: example (train/001.treex#387): standardkraven/CJ (attached to 'Stressen'); CC: trångboddheten, pressen, miljön
            # Stressen standardkraven, trångboddheten, den ekonomiska pressen och miljön skapar svårigheter för en familj.
            # Stress of the standard requirements, overcrowding, the financial press and the environment creates difficulties for a family.
            ###!!! The example is strange and I still don't understand it fully. The above translation is from Google so I may be missing something.
            $afun = 'Atr';
        }

        # Other head
        elsif ( $deprel eq 'HD' )
        {
            # train/001.treex#4 ('sedan')
            $afun = 'Adv';
        }

        # Subordinate clause minus subordinating conjunction
        elsif ( $deprel eq 'BS' )
        {
            $afun = 'Adv';
        }

        # Second conjunct (sister of conjunction) in binary branching analysis
        elsif ( $deprel eq 'C+' )
        {
            # train/001.treex#120 ('hjälpsamhet' = 'helpfulness')
            $afun = 'CoordArg';
        }

        # Sister of first conjunct in binary branching analysis of coordination
        elsif ( $deprel eq 'CC' )
        {
            # DZ: Zdeněk's approach seems to work even without this.
            #$afun = 'CoordArg';
        }

        # Infinitive phrase minus infinitive marker
        elsif ( $deprel eq 'IF' )
        {
            # DZ: This tag does not occur in the treebank.
        }

        # Complement of preposition
        elsif ( $deprel eq 'PA' )
        {
            $afun = 'Adv';
        }

        # Verb group
        elsif ( $deprel eq 'VG' )
        {
            $afun = 'Atv';
        }

        $afun = $afun || $pos2afun{$pos} || 'NR';
        $node->set_afun($afun);
    }
}


sub restructure_coordination {
    my ($self, $root) = @_;

    foreach my $last_member (grep {$_->conll_deprel =~ /^(CC|\+F)/ and
                                       not grep {$_->conll_deprel =~ /^(CC|\+F)/} $_->get_children}
                                 map {$_->get_descendants} $root->get_children) {

        my ($coord_root) = (grep {$_->conll_deprel eq '++'} $last_member->get_children,
                            grep {$_->conll_deprel eq 'IK'} $last_member->get_children);

        if ($coord_root) {

            # climbing up to collect coordination members
            my @members = ( $last_member );
            my $node = $last_member;
            while ( $node->conll_deprel =~ /^(CC|\+F)/ ) {
                $node = $node->get_parent;
                push @members, $node;
            }

            # TODO: rehanging commas in multiple coordinations

            $coord_root->set_parent($members[-1]->get_parent);
            $coord_root->set_afun('Coord');

            foreach my $member (@members) {
                $member->set_parent($coord_root);
                $member->set_is_member(1);
                $member->set_conll_deprel($members[-1]->conll_deprel);
            }
        }
    }
}


1;

=over

=item Treex::Block::A2A::SV::CoNLL2PDTStyle

Converts trees coming from the Swedish Mamba Treebank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>, Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
