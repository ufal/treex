package Treex::Block::HamleDT::FA::Harmonize;
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
    default       => 'fa::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Persian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone( $zone );
    # Adjust the tree structure.
    # Phrase-based implementation of tree transformations (5.3.2016).
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
# https://wiki.ufal.ms.mff.cuni.cz/_media/user:zeman:treebanks:persian-dependency-treebank-version-0.1-annotation-manual-and-user-guide.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {
        # The corpus contains the following 44 dependency relation tags:
        # SBJ OBJ NVE ENC VPP OBJ2 TAM MOS PROG ADVC VCL VPRT LVP PARCL ADV AJUCL PART VCONJ
        # NPREMOD NPOSTMOD NPP NCL MOZ APP NCONJ NADV NE MESU NPRT COMPPP ADJADV ACL AJPP NEZ AJCONJ APREMOD APOSTMOD
        # PREDEP POSDEP PCONJ AVCONJ PRD ROOT PUNC
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
        # An error? There is also a 'PRD' (instead of 'ROOT') that depends directly on the root.
        if ( $deprel eq 'ROOT' || $deprel eq 'PRD' && $parent==$root )
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
        # PRD: Predicate of a subordinate or relative clause, attached to the subordinating conjunction.
        #     Example: amädäm ta bebinäm = I-came to I-see = I came to see (bebinäm is PRD of ta).
        elsif ( $deprel eq 'PRD' )
        {
            $deprel = 'SubArg';
        }
        # Subject.
        elsif ( $deprel eq 'SBJ' )
        {
            $deprel = 'Sb';
        }
        # OBJ:  Object.
        # VPP:  Prepositional complement of verb (this is the label of the preposition, so ve also need to switch it with the NP later).
        # VPRT: Sometimes preposition-noun-verb is considered a compound verb. Then the preposition is VPRT: be däst avärd = to hand brought = gained.
        # LVP:  Light verb particle. Only the compound light verb "pejda kärdän" (to find) (pejda is LVP).
        # VCL:  Complement clause of verb: midanäm ke miajäd = I know that he comes.
        # NPRT: Particle (preposition) of infinitive (infinitives behave as nouns in Persian).
        # ACL:  Complement clause of adjective: agah hästäm ke miaji = aware am that he-comes = I am aware that he will come.
        # AJPP: Prepositional complement of adjective: ašna ba äkkasi = familiar with photography.
        # NEZ:  Ezafe complement of adjective (see MOZ below for ezafe explanation): negäran-e u = anxious-EZAFE him = anxious about him.
        elsif ( $deprel =~ m/^(OBJ2?|VPP|VPRT|LVP|VCL|NPRT|ACL|AJPP|NEZ)$/ )
        {
            $deprel = 'Obj';
        }
        # NVE: Non-verbal element of a compound verb (compound predicate).
        # ENC: Enclitic non-verbal element of a compound verb.
        # MOS: Mosnad. A property ascribed to the subject using verbs such as šodän (to become), budän (to be), ästän (to be) etc.
        #      Example: u  doktor äst
        #      Gloss:   he doctor is
        # NE: Non-verbal element of compound infinitive (Persian infinitives behave (and are tagged?) as nouns).
        elsif ( $deprel =~ m/^(NVE|ENC|MOS|NE)$/ )
        {
            $deprel = 'Pnom';
        }
        # TAM: Tamiz: a property ascribed by the subject to the object (simplified).
        # Typically occurs with verbs like namidän (to name), xandän (to call), danestän (to consider) etc.
        # Example: ali ra märd -i xub mipendarim
        # Gloss: Ali ACC man INDEF good consider/PRES-1ST-PL
        # Translation: We consider Ali a good man.
        # The relation between "mipendarim" and "xub" is labeled "TAM".
        elsif ( $deprel eq 'TAM' )
        {
            $deprel = 'Atv';
        }
        # ADVC: Adverbial complement of verb: tehran mandäm = Tehran stay/PAST-1ST-SG = I stayed in Tehran.
        # ADV: Adverbial modifier of verb: bäraje xärid räftäm = for shopping I-went = I went for shopping.
        # AJUCL: Adjunct clause: ägär bijaji xošhal mišäväm = if you-come happy I-become = I'll be happy if you come. (ägär is AJUCL)
        # PARCL: Participle clause.
        #    In coordination of two verbs with the same subject and different verbs of the same tense-aspect-mood,
        #    the first verb can be changed into the past participle form. In such a case, the transformed verb
        #    depends on the verb with normal inflection and the relation is labeled PARCL.
        #    Example: be xane räfte xabidäm = to home gone I slept = I went home and slept (or: Having gone home, I slept)
        # NADV: Adverbial modifier of compound predicate, attached to its non-verb component.
        # AJADV: Adverbial complement of adjective
        # ADJADV: Adverbial complement of adjective: taksi sävar šodäm = taxi riding I-became (taksi is ADJADV of sävar).
        # APREMOD: Adjective pre-modifier by an adverb: besjar šad = very happy.
        # APOSTMOD: Adjective post-modifier by another adjective: pirahän-e abi-je asemani = shirt-EZAFE blue-EZAFE sky = a sky blue shirt.
        elsif ( $deprel =~ m/^(ADVC|ADV|AJADV|AJUCL|PARCL|NADV|ADJADV|APREMOD|APOSTMOD)$/ )
        {
            if($node->form() =~ m/^(نه|غیر)$/)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # PROG: Auxiliary forming the progressive tense.
        # Example:     daštäm           miräštäm
        # Gloss:       have-PAST-1ST-SG go-PAST-PROG-1ST-SG
        # Translation: I was going.
        # Daštäm is the auxiliary.
        elsif ( $deprel eq 'PROG' )
        {
            $deprel = 'AuxV';
        }
        # PART: Interrogative particle.
        #     The words "aja" and "mägär" turn the sentence into a yes/no question.
        #     The relation between the main verb and these particles is labeled "PART".
        elsif ( $deprel eq 'PART' )
        {
            # The Czech PDT tagset does not seem to provide a better label than AuxV.
            # There might be something in the Arabic PADT: AuxM?
            $deprel = 'AuxV';
        }
        # NPREMOD: Pre-modifier of noun (superlative adjective, numeral, title).
        # NPOSTMOD: Post-modifier of noun (positive and comparative adjective, numeral).
        # NPP: Prepositional phrase modifying a noun, e.g.: jedal dar tasuki = battle in Tasooki
        # NCL: Clause modifying a noun, e.g.: märd -i ke didi = man a that you-saw = the man you saw
        # MOZ: Ezafe dependent.
        #    Ezafe is the suffix "-e" pronounced after a Persian noun, usually not visible in the Perso-Arabic script (=> it has no node in the tree).
        #    It signifies an ezafe construction that connects the head noun to the following modifier noun (cf. with pre/postpositions).
        #    Its possible meanings are:
        #        - possession: ketab-e häsän = book of Hassan = Hassan's book
        #        - first name - last name
        #        - etc.
        #    Ezafe dependent is the noun after ezafe.
        # MESU: Measure (a measurement unit between numeral and counted noun): do dželd ketab = two volume book
        elsif ( $deprel =~ m/^(NPREMOD|NPOSTMOD|NPP|NCL|MOZ|MESU)$/ )
        {
            $deprel = 'Atr';
        }
        # COMPPP: Comparative preposition: behtär äz servät = better than wealth; äz is COMPPP of behtär.
        #     http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s07s09s02.html
        #     In PDT, comparative constructions "better than something" are analyzed as ellipsis for "better than something is".
        #     They are thus tagged 'ExD', which does not say much (many other very different cases are tagged 'ExD', too).
        #     We may want to consider introducing special deprel for comparative constructions instead.
        elsif ( $deprel eq 'COMPPP' )
        {
            $deprel = 'ExD';
        }
        # PREDEP: Pre-dependent in cases that do not have their own specific tag.
        #     Most common: relation between a noun and its accusative postposition "-ra": äli -ra didäm = Ali ACC I-saw = I saw Ali (äli is PREDEP of -ra).
        #     Also common: between coordinating conjunction and the preceding (non-head): xandäm vä neveštäm = I-read and I-wrote (xandäm is PREDEP of vä).
        #     All pre-dependents (other than NPRT and NE) of infinitives used as nouns are PREDEP.
        #     Words like hätta ("even"), häm, nä are PREDEP if they modify a non-verb: hätta äli fähmid = even Ali learnt.
        # POSDEP: Post-dependent in cases that do not have their own specific tag.
        #     Common use: relation between a preposition and its noun: be äli = to Ali (äli is POSDEP of be).
        #     Common use: relation between coordinating conjunction and the following (non-head) word (noun, adjective, adverb or preposition).
        elsif ( $deprel =~ m/^(PREDEP|POSDEP)$/ )
        {
            if($ppos eq 'adp')
            {
                $deprel = 'PrepArg';
            }
            elsif($ppos eq 'conj' && $parent->get_iset('conjtype') eq 'coor')
            {
                $deprel = 'CoordArg';
            }
            else
            {
                $deprel = 'AuxZ';
            }
        }
        # VCONJ: Coordinating conjunction between two verbs (the one appearing earlier is dependent, the one appearing later is the head)
        # or the dependent verb conjunct if there is no coordinating conjunction.
        # NCONJ: Same for nouns.
        # AJCONJ: Same for adjectives.
        # PCONJ: Same for prepositions: där tehran vä ba ma bud = in Tehran and with us was = he was in Tehran and with us (där is PCONJ of vä).
        # AVCONJ: Same for adverbs.
        elsif ( $deprel =~ m/^(VCONJ|NCONJ|AJCONJ|PCONJ|AVCONJ)$/ )
        {
            $deprel = 'Coord';
        }
        # Second member of apposition: sädi šaer -e irani = Saadi poet EZAFE Iranian = Saadi, the Iranian poet
        elsif ( $deprel eq 'APP' )
        {
            $deprel = 'Apposition';
        }
        # Punctuation.
        elsif ( $deprel eq 'PUNC' )
        {
            my $arabic_comma = "\x{60C}";
            if($node->form() =~ m/^[,$arabic_comma]$/)
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
            # The sentence-final punctuation should get 'AuxK' but we will also have to reattach it and we will retag it at the same time.
        }
        $node->set_deprel($deprel);
    }
    # Sentence test/001.treex.gz#41: conjunction 'va' m-tagged 'CONJ' (correct) but s-tagged 'PUNC' instead of *CONJ.
    # Thus it is not coordination, thus the 'PREDEP' verb attached to it should not get the 'CoordArg' pseudo-deprel.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'CoordArg' && $node->parent()->deprel() ne 'Coord')
        {
            # I do not know what the sentence means and what we should do in this strange case.
            $node->set_deprel('ExD');
        }
        # Consolidate information about participants of coordination so that it can be properly detected.
        my $cnode_type = $self->get_cnode_type($node);
        ###!!! We now do not rely on wild->coordinator/conjunct when detecting coordination.
        ###!!! However, it seems that in this treebank it will be more difficult to get rid of it.
        ###!!! The if-elsif blocks below contained various adjustments of wild attributes; maybe we have to adjust the deprels or is_member instead?
        my $wild = $node->wild();
        $wild->{cnode_type} = $cnode_type;
        if(!defined($cnode_type) || $cnode_type eq 'hmember')
        {
        }
        elsif($cnode_type eq 'nhmember')
        {
        }
        elsif($cnode_type =~ m/^(conjunction|punctuation)$/)
        {
        }
    }
}



#------------------------------------------------------------------------------
# Tells about a node its type with respect to coordinations.
# A node s-tagged CoordArg is a non-head conjunct. (Note that the first
# conjunct is usually the head but in verb coordinations the last conjunct is
# the head.)
# A node s-tagged Coord is either a non-head conjunct or a conjunction.
# We do not rely on the m-tag of the node. Instead:
# If the node has at least one child s-tagged CoordArg, it is a conjunction.
# Otherwise, it is a conjunct.
# A node that has an s-tag other than Coord and CoordArg is the head conjunct
# if it has at least one child s-tagged Coord.
# A node s-tagged AuxX is a coordination delimiter if it has a sibling s-tagged
# Coord (its parent need not necessarily be s-tagged Coord; it could be the
# head conjunct).
# Note that the function does not care about modifiers of coordinations.
#------------------------------------------------------------------------------
sub get_cnode_type
{
    my $self = shift;
    my $node = shift;
    my $result; # hmember | nhmember | conjunction | punctuation | undef
    my $deprel = $node->deprel();
    if($deprel eq 'CoordArg')
    {
        $result = 'nhmember';
    }
    elsif($deprel eq 'AuxX')
    {
        my @siblings = grep {$_!=$node} ($node->parent()->children());
        $result = 'punctuation' if(grep {$_->deprel() eq 'Coord'} (@siblings));
    }
    else
    {
        my @children = $node->children();
        if($deprel eq 'Coord')
        {
            if(grep {$_->deprel() eq 'CoordArg'} (@children))
            {
                $result = 'conjunction';
            }
            else
            {
                $result = 'nhmember';
            }
        }
        elsif(grep {$_->deprel() eq 'Coord'} (@children))
        {
            $result = 'hmember';
        }
    }
    return $result;
}



1;

=over

=item Treex::Block::HamleDT::FA::Harmonize

Converts Persian dependency trees from CoNLL to the style of
HamleDT (Prague). Morphological tags will be decoded into
Interset and to the 15-character positional tags of PDT.

=back

=cut

# Copyright 2012, 2014, 2016 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
