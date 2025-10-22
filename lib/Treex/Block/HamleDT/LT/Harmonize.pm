package Treex::Block::HamleDT::LT::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'lt::multext',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Lithuanian tree and transforms it to adhere to the HamleDT
# guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # HamleDT::Harmonize will call methods of this block in the following order:
    # - fix_morphology() ... called after converting the tags to Interset
    # - convert_deprels()
    # - fix_annotation_errors()
    return;
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
    # Some nodes have no tags and the Interset driver is not happy about it.
    # Typically these are punctuation nodes. Multext-East does not define
    # a common tag for punctuation but some Multext-based tagsets use "Z",
    # and that is what Interset eventually expects.
    my $tag = $node->tag();
    if(!defined($tag) || $tag eq '')
    {
        $tag = 'Z';
    }
    return $tag;
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
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form() // '';
        # Several times, a quotation mark is XPOS-tagged "Aux", which should
        # have been its afun (deprel), and the afun is "-". By the time this
        # method is called, $node->tag() has been copied as original tag to
        # $node->conll_pos(), so we must update it there too.
        my $origtag = $node->conll_pos() // '';
        if($form =~ m/^\pP+$/ && $origtag eq 'Aux')
        {
            $origtag = 'Z';
            $node->set_conll_pos($origtag);
            $node->set_tag($origtag);
            # Decode it to Interset again.
            $self->decode_iset($node);
            # The corresponding PDT-like tag will be created after this method
            # has finished, so we do not have to care of it now.
        }
        # Annotation error: conjunction "kad" ("that") annotated as punctuation.
        if($node->is_punctuation() && $node->form() =~ m/^kad$/i)
        {
            $origtag = 'Cg';
            $node->set_conll_pos($origtag);
            $node->set_tag($origtag);
            # Decode it to Interset again.
            $self->decode_iset($node);
            # The corresponding PDT-like tag will be created after this method
            # has finished, so we do not have to care of it now.
        }
        my $lemma = $node->lemma() // '';
        # Fix Interset features of pronominal words.
        # The original Lithuanian Multext tagset does not distinguish pronoun types at all.
        if($node->is_pronominal())
        {
            # Personal pronouns:
            # 1 Sing: aš manęs man mane manyje manimi
            # 1 Dual: mudu mudvi mudviejų mudviem mudviese
            # 1 Plur: mes mūsų mums mus mumis mumyse
            # 2 Sing: tu tavęs tau tave tavyje tavimi
            # 2 Dual: judu judvi judviejų judviem judviese
            # 2 Plur: jūs jūsų jums jus jumis jumyse
            # 3 Sing Masc: jis jo jam jį juo jame jo
            # 3 Sing Fem:  ji jos jai ją ja joje
            # 3 Dual Masc: juodu jiedu jųdviejų jodviem jiedviese
            # 3 Dual Fem:  jiedvi jųdviejų jodviem jiedviese
            # 3 Plur Masc: jie jų jiems juos jais juose
            # 3 Plur Fem:  jos jų joms jas jomis jose
            # Reflex: savęs sau save savimi savim savyje savy
            # The data already indicate number and case; both singular ("I") and plural ("we") have the same lemma ("aš").
            if($lemma =~ m/^(aš|tu|jis|savęs)$/)
            {
                $node->iset()->set('prontype', 'prs');
                if($lemma eq 'aš')
                {
                    $node->iset()->set('person', '1');
                }
                elsif($lemma eq 'tu')
                {
                    $node->iset()->set('person', '2');
                }
                elsif($lemma eq 'jis')
                {
                    $node->iset()->set('person', '3');
                }
                else # savęs
                {
                    $node->iset()->set('reflex', 'yes');
                }
            }
            # Demonstrative pronouns/determiners.
            elsif($lemma =~ m/^(šis|tas|toks|anas|šitas)$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('prontype', 'dem');
            }
            # Interrogative/relative pronouns/determiners.
            # kas = who: does not inflect for gender
            # kuris = which: inflects for gender
            # koks = what kind of: ditto
            # kelintas = what rank (interrogative ordinal): ditto
            # katras = which of two: probably ditto
            elsif($lemma =~ m/^(kas|kuris|koks|kelintas|katras)$/)
            {
                $node->iset()->set('pos', 'adj') unless($lemma eq 'kas');
                $node->iset()->set('prontype', 'int', 'rel');
            }
            # Total pronouns.
            # visas = all: inflects for gender
            # kiekvienas = every: ditto
            # abu = both: tagged as cardinal numeral, not pronoun (as in Czech); but inflects for gender
            elsif($lemma =~ m/^(visas|kiekvienas)$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('prontype', 'tot');
            }
            # Emphatic pronoun.
            # pats = oneself: inflects for gender
            elsif($lemma =~ m/^(pats)$/)
            {
                $node->iset()->set('pos', 'adj');
                $node->iset()->set('prontype', 'emp');
            }
            # Negative pronoun.
            # niekas = nobody, nothing: does not inflect for gender
            # joks = no, none: inflects for gender
            elsif($lemma =~ m/^(niekas|joks)$/)
            {
                $node->iset()->set('pos', 'adj') unless($lemma eq 'niekas');
                $node->iset()->set('prontype', 'neg');
            }
            # Indefinite pronouns are composed of two tokens, one of them is interrogative.
            # At present they are represented as single nodes in ALKSNIS but it may be changed in the future.
            # kažkas = unknown something
            # kas nors = unspecific something
            # kai kas = specific something
            # bet kas = anything
            else
            {
                $node->iset()->set('prontype', 'ind');
            }
        }
        # Pronominal adverbs were not previously tagged as pronominal, so they
        # were not caught in the previous branch (is_pronominal()) and we must
        # do them here.
        if($node->is_adverb())
        {
            # Interrogative/relative adverbs.
            # kur = where
            # kada = when
            # kaip = how
            # kodėl = why
            if($lemma =~ m/^(kur|kada|kaip|kodėl)$/)
            {
                $node->iset()->set('prontype', 'int', 'rel');
            }
        }
        # The definiteness feature seems to be relevant for ordinal but not for cardinal numerals.
        # Yet occasionally a cardinal numeral is tagged as indefinite. Fix it.
        if($node->is_cardinal())
        {
            $node->iset()->clear('definite');
        }
        # A couple finite verbs lack the mood feature. Set them to indicative.
        if($node->is_finite_verb() && $node->iset()->mood() eq '')
        {
            $node->iset()->set_mood('ind');
        }
        # Fix Interset features of conjunctions.
        # The original Lithuanian Multext tagset does not distinguish coordinating and subordinating conjunctions.
        if($node->is_conjunction())
        {
            # "ar" can be both coordinating ("or") and subordinating ("if")
            if($lemma eq 'ar')
            {
                if($node->deprel() eq 'AuxC')
                {
                    $node->iset()->set('conjtype', 'sub');
                }
                else
                {
                    $node->iset()->set('conjtype', 'coor');
                }
            }
            # ir, o, bei = and
            # bet = but
            # ar, arba = or (but see above for "ar")
            # tačiau, vis dėlto = however
            # tad, tai, taigi = so, therefore, thus
            # kuo = wherewith
            # kadangi = whereas
            # ne = no??? (neither-no?)
            # tegul = let's???
            elsif($lemma =~ m/^(ir|bet|o|arba|bei|beigi|tačiau|vis dėlto|tai|taigi|kuo|kadangi|tad)$/)
            {
                $node->iset()->set('conjtype', 'coor');
            }
            # kad, jog, tuo = that
            # kai = when
            # kaip, lyg, tarsi = as, like
            # nei ... kaip ... = as ... as ...
            # nes = because
            # jei, jeigu = if
            # nebent = unless
            # nors = although
            # negu = than
            # kol = until
            # užuot = instead of
            elsif($lemma =~ m/^(kad|jog|tuo|kai|kaip|lyg|tarsi|nei|nes|jei|jeigu|nebent|nors|negu|kol|užuot)$/)
            {
                $node->iset()->set('conjtype', 'sub');
            }
        }
        # All abbreviations (original tag 'Ys') have unknown part of speech.
        # The abbreviation of "metus" ("year") should be noun. Later when we
        # convert from Prague to UD, it will help us to choose 'obl' instead of 'advmod'.
        if($node->lemma() =~ m/^m\.?$/ && $node->is_abbreviation() && $node->iset()->pos() eq '')
        {
            $node->iset()->set('pos', 'noun');
        }
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
    # First loop: copy deprel to deprel and convert _CO and _AP to is_member.
    # Leave everything else untouched until we know that is_member is set correctly for all nodes.
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # There were erroneous afuns with trailing spaces in Alksnis!
        $deprel =~ s/\s+$//;
        $deprel =~ s/^\s+//;
        $deprel =~ s/^aux([a-z])$/Aux\U$1/i;
        # The _Co suffix signals conjuncts.
        # The _Ap suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($deprel =~ s/_(Co|Ap)$//i || $deprel =~ s/_Co_/_/i)
        {
            $node->set_is_member(1);
        }
        # Annotation errors: Coord must not be leaf.
        if($deprel eq 'Coord' && $node->is_leaf())
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            elsif($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        $node->set_deprel($deprel);
    }
    # Second loop: process chained dependency labels and decide what nodes are ExD, Coord, Apos, AuxP or AuxC.
    # At the same time translate the other deprels to the dialect of HamleDT.
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        my $parent = $node->parent();
        # There are chained dependency labels that describe situation around elipsis.
        # They ought to contain an ExD, which may be indexed (e.g. ExD0).
        # The tag before ExD describes the dependency of the node on its elided parent.
        # The tag after ExD describes the dependency of the elided parent on the grandparent.
        # Example: ADV_ExD0_PRED_CO
        # Similar cases in PDT get just ExD.
        if($deprel =~ m/ExD/i)
        {
            # If the chained label is something like COORD_ExD0_OBJ_CO_ExD1_PRED,
            # this node should be Coord and the conjuncts should get ExD.
            # However, we still cannot set deprel=ExD for the conjuncts.
            # This would involve traversing also AuxP nodes and nested Coord, so we need to have all Coords in place first.
            if($deprel =~ m/^Coord/i)
            {
                $node->set_deprel('Coord');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            elsif($deprel =~ m/^Apos/i)
            {
                $node->set_deprel('Apos');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            # Do not change AuxX and AuxG either.
            # These deprels reflect more what the node is than how it modifies its parent.
            elsif($deprel =~ m/^(Aux[CPGX])/)
            {
                $node->set_deprel($1);
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            else
            {
                $node->set_deprel('ExD');
            }
        }
        # Deprel may have changed in the previous if, let's update $deprel.
        $deprel = $node->deprel();
        if($deprel =~ s/_Par$//i)
        {
            ###!!! Už na to nemám nervy. Parenteze se v PDT moc často nevyskytovala,
            ###!!! takže její převod a interakce s koordinací a dalšími konstrukcemi
            ###!!! asi není dotažená a občas mi to nějak hapruje.
            ###!!! Jeden PredN_Par napojený jako shared modifier na Coord spojku
            ###!!! se mi tam rozsypal a nepřevedl, tak ho prostě násilím předělám
            ###!!! na obyčejný Pred.
            if($deprel eq 'PredN')
            {
                $deprel = 'Pred';
            }
            else
            {
                $node->set_is_parenthesis_root(1);
            }
        }
        if($deprel =~ m/^PredV_(Sub|Obj|Adj|Atr)$/i)
        {
            $deprel = $1;
        }
        # Sub is subject; in PDT it is labeled "Sb".
        # One subject in Alksnis is by error labeled "Suj".
        if($deprel =~ m/^Su[bj]$/i)
        {
            $deprel = 'Sb';
        }
        # PredN seems to be the nominal predicate. If the copula "būti" is present,
        # the topology is similar to that of Pnom in Czech. But in Lithuanian,
        # the copula seems to be omitted often.
        # My original observation (maybe on an older version of ALKSNIS?) was
        # that if the copula is missing, the nominal predicate (PredN) is
        # attached to the subject, which is the opposite of what we want in UD.
        # Since we are now doing just Prague harmonization (and there is no
        # similar construction in Czech), we just leave PredN there for further
        # processing.
        # HOWEVER! In her mail from 2020-05-13, Bernadeta says that in a main
        # clause, the nominal predicate should become the head. It should be
        # attached to the artificial root but it should still have the PredN
        # afun instead of Pred. Example:
        # Specialiosios tarnybos įpareigotos ištirti sutartis.
        # Special services (are) obliged to investigate contracts.
        # The participle įpareigotos "obliged" is tagged VERB but still treated
        # as a nominal predicate, its parent is the root and its afun is PredN.
        # Also see the subtypes PredN_Sub, PredN_Obj etc. below.
        if($deprel eq 'PredN')
        {
            if($parent->is_root())
            {
                $deprel = 'Pred';
            }
            else
            {
                my $plemma = $parent->lemma();
                if(defined($plemma) && $plemma eq 'būti')
                {
                    $deprel = 'Pnom';
                }
            }
        }
        # PredV seems to be often an infinitive completing another verb.
        if($deprel =~ m/^PredV$/i)
        {
            $deprel = 'Obj';
        }
        # AuxF is a formula in brackets after a phrase or clause (p = 0,39).
        if($deprel =~ m/^AuxF$/i)
        {
            $deprel = 'Pred';
        }
        # AuxL is the first name attached to the last name.
        if($deprel =~ m/^AuxL$/i)
        {
            $deprel = 'Atr';
        }
        # AtrQ seems to be a genitive noun phrase with partitive interpretation,
        # attached to a quantifier. The documentation explains it as "Atributas
        # (kokybės turinio)", which Google translates as "Attribute (Quality
        # Content)".
        if($deprel =~ m/^AtrQ$/i)
        {
            $deprel = 'Atr';
        }
        # There is one occurrence of relation 'Aux?'. It is a typo in the relation
        # label. In fact, this particular occurrence should be Coord.
        if($deprel eq 'Aux?')
        {
            $deprel = 'Coord';
        }
        if($deprel =~ m/^Aux$/i)
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            elsif($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            elsif($node->is_numeral())
            {
                $deprel = 'Atr';
            }
            elsif($node->is_adposition())
            {
                $deprel = 'AuxP';
            }
            else
            {
                $deprel = 'AuxZ';
            }
        }
        # Rgp is an error (it is the POS tag for adverbs, not an afun).
        if($deprel =~ m/^Rgp$/i)
        {
            $deprel = 'Adv';
        }
        # Adj is Lithuanian-specific and it probably means "adjunct".
        if($deprel eq 'Adj')
        {
            if($parent->is_noun() || $parent->is_numeral())
            {
                $deprel = 'Atr';
            }
            else
            {
                $deprel = 'Adv';
            }
        }
        # Bernadeta: Pred_Atr, Pred_Sub etc. designate types of subordinate
        # clauses, i.e., modifying, subjective, objective, etc.
        # Dan: Then I should drop the 'Pred_' and keep the actual type. However,
        # I believe I also saw an example where Pred_Sub modified a coreferential
        # pronoun, which serves as a subject of the matrix clause, and then it
        # would be better to make the clause Atr of the pronoun, not Sb!
        # Example:
        # tai, ką mes kalbame = what we are talking about (lit. "that, what we discuss")
        if($deprel =~ m/^Pred_(Sub|Obj|Adj|Atr|Adv)$/ && $parent->is_demonstrative())
        {
            $deprel = 'Atr';
        }
        # Predicate of a subject clause.
        elsif($deprel eq 'Pred_Sub')
        {
            $deprel = 'Sb';
        }
        # Predicate of an object clause.
        elsif($deprel eq 'Pred_Obj')
        {
            $deprel = 'Obj';
        }
        # Predicate of an attributive clause (modifying a nominal).
        elsif($deprel eq 'Pred_Atr')
        {
            $deprel = 'Atr';
        }
        # Pred_Adv is the predicate of an adverbial clause (possibly under AuxC).
        # Loic Boizou: Pred_Adj (adjunct clause) was a mistake, it does not
        # appear in newer versions and should be treated as Pred_Adv.
        elsif($deprel =~ m/^Pred_Ad[vj]$/)
        {
            $deprel = 'Adv';
        }
        # Similarly to Pred_*, PredN_Sub etc. also designate types of
        # subordinate clauses but this time the predicate of the subordinate
        # clause is nominal without a copula. We will treat PredN_Sub similarly
        # to Pred_Sub (including the possibility that it is attached via a
        # demonstrative pronoun). Note however that we lose information that
        # is useful for the later conversion to UD: if the subject is a noun,
        # it will be converted to 'nsubj', although if it was a nominal
        # predicate, it should actually be converted to 'csubj'. ###!!!
        if($deprel =~ m/^PredN_(Sub|Obj|Adj|Atr)$/ && $parent->is_demonstrative())
        {
            $deprel = 'Atr';
        }
        # Nominal predicate of a subject clause.
        elsif($deprel eq 'PredN_Sub')
        {
            $deprel = 'Sb';
        }
        # Nominal predicate of an object clause.
        elsif($deprel eq 'PredN_Obj')
        {
            $deprel = 'Obj';
        }
        # Nominal predicate of an attributive clause (modifying a nominal).
        elsif($deprel eq 'PredN_Atr')
        {
            $deprel = 'Atr';
        }
        # Nominal predicate of an adverbial clause (possibly under AuxC).
        elsif($deprel eq 'PredN_Adv')
        {
            $deprel = 'Adv';
        }
        # There is also one occurrence of PredV_Adv. I do not know how it differs
        # from Pred_Adv.
        if($deprel eq 'PredV_Adv')
        {
            $deprel = 'Adv';
        }
        # Combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if($deprel =~ m/^((Atr)|(Adv)|(Obj))_?((Atr)|(Adv)|(Obj))/i)
        {
            $deprel = 'Atr';
        }
        # AuxG cannot be conjunct in HamleDT but it happens in AGDT (and we cannot be sure that it does not happen in Alksnis).
        if($node->deprel() eq 'AuxG' && $node->is_member())
        {
            $node->set_is_member(undef);
        }
        # Several times, a quotation mark is XPOS-tagged "Aux", which should have been its afun (deprel),
        # and the afun is "-". We have already fixed the XPOS tag in fix_morphology() because
        # that method is called before converting the tags, unlike this one. But now we also must
        # fix the dependency relation.
        # There are also a few non-punctuation nodes that lack the afun.
        if($deprel eq '-')
        {
            if($node->is_punctuation())
            {
                $deprel = 'AuxG';
            }
            elsif($node->is_conjunction())
            {
                # Is it a coordination head?
                my @members = grep {$_->is_member()} ($node->children());
                if(scalar(@members)==0)
                {
                    $deprel = 'AuxY';
                }
                else
                {
                    $deprel = 'Coord';
                }
            }
            else
            {
                $deprel = 'ExD';
            }
        }
        # Parenthetical.
        if($deprel =~ m/^par$/i)
        {
            $node->set_is_parenthesis_root(1);
            $deprel = 'Pred';
        }
        $node->set_deprel($deprel);
    }
    # Third loop: we still cannot rely on is_member because it is not guaranteed that it is always set directly under COORD or APOS.
    # The source data follow the PDT convention that AuxP and AuxC nodes do not have it (and thus it is marked at a lower level).
    # In contrast, Treex marks is_member directly under Coord or Apos. We cannot convert it later because we need reliable is_member
    # for deprel conversion.
    foreach my $node (@nodes)
    {
        # no is_member allowed directly below root
        if($node->is_member() and $node->parent()->is_root())
        {
            $node->set_is_member(undef);
        }
        if($node->is_member())
        {
            my $new_member = $self->_climb_up_below_coap($node);
            if($new_member && $new_member != $node)
            {
                $new_member->set_is_member(1);
                $node->set_is_member(undef);
            }
        }
    }
    # Fourth loop: if there are inconsistencies in coordination even after moving is_member up to Aux[PC], fix them.
    foreach my $node (@nodes)
    {
        # A node labeled Coord or Apos must have at least one member child.
        if($node->deprel() =~ m/^(Coord|Apos)$/)
        {
            my @children = $node->get_children({'ordered' => 1});
            my @members = grep {$_->is_member()} (@children);
            if(scalar(@members)==0)
            {
                # Are there candidates for members among the children?
                my @non_aux_children = grep {$_->deprel() !~ m/^Aux/} (@children);
                if(scalar(@non_aux_children)>0)
                {
                    foreach my $child (@non_aux_children)
                    {
                        $child->set_is_member(1);
                    }
                }
                # If we cannot make any child a member, we must replace the Coord|Afun label with something else.
                else
                {
                    if($node->form() eq ',')
                    {
                        $node->set_deprel('AuxX');
                    }
                    elsif($node->is_punctuation())
                    {
                        $node->set_deprel('AuxG');
                    }
                    else
                    {
                        $node->set_deprel('AuxY');
                    }
                }
            }
        }
        # If a node is not labeled Coord or Apos, it cannot have member children.
        else
        {
            # If a conjunction or punctuation node has children with is_member set, it must be labeled as Coord or Apos.
            my @children = $node->get_children({'ordered' => 1});
            my @members = grep {$_->is_member()} (@children);
            if(scalar(@members)>0)
            {
                if($node->iset()->pos() =~ m/^(conj|punc|part|adv)$/)
                {
                    $node->set_deprel('Coord');
                }
                else
                {
                    foreach my $member (@members)
                    {
                        $member->set_is_member(undef);
                    }
                }
            }
        }
        # Punctuation can have children only if it heads coordination or apposition.
        # By default we assume apposition, provided the configuration seems compatible with apposition.
        # Note that even if the punctuation node's afun is currently Coord, it is not guaranteed that its children are marked as conjuncts.
        # Same for coordinating conjunctions.
        if($node->is_punctuation() || $node->deprel() eq 'AuxY')
        {
            my @children = $node->get_children({'ordered' => 1});
            my @members = grep {$_->is_member()} (@children);
            if(scalar(@members)==0)
            {
                # Before we decide that it is apposition or coordination, let's get rid of children that are themselves punctuation.
                my @punctchildren = grep {$_->is_punctuation()} (@children);
                my @nopunctchildren = grep {!$_->is_punctuation()} (@children);
                foreach my $child (@punctchildren)
                {
                    # For now, we simply attach the child higher. It is not safe
                    # w.r.t. nonprojectivities but there is no guarantee anyway
                    # that punctuation is projective, so we will have to look
                    # into that later.
                    my $newparent = $node->parent();
                    while($newparent->is_punctuation() && !$newparent->is_root())
                    {
                        $newparent = $newparent->parent();
                    }
                    $child->set_parent($newparent);
                    $child->set_is_member(undef);
                }
                if(scalar(@nopunctchildren)==2 &&
                    $nopunctchildren[0]->ord() < $node->ord() &&
                    $nopunctchildren[1]->ord() > $node->ord())
                {
                    $node->set_deprel('Apos');
                    $nopunctchildren[0]->set_is_member(1);
                    $nopunctchildren[1]->set_is_member(1);
                }
                elsif(scalar(@nopunctchildren)>=2)
                {
                    $node->set_deprel('Coord');
                    foreach my $child (@nopunctchildren)
                    {
                        $child->set_is_member(1);
                    }
                }
                elsif(scalar(@nopunctchildren)==1)
                {
                    # Attach the child as my sibling or even higher, if my parent is also punctuation.
                    my $newparent = $node->parent();
                    while($newparent->is_punctuation() && !$newparent->is_root())
                    {
                        $newparent = $newparent->parent();
                    }
                    $nopunctchildren[0]->set_parent($newparent);
                    $nopunctchildren[0]->set_is_member(undef);
                }
            }
        }
    }
    # Fifth loop: finish propagating ExD down the tree at coordination and apposition.
    foreach my $node (@nodes)
    {
        if($node->wild()->{'ExD conjuncts'})
        {
            # set_real_deprel() goes down if it sees Coord, Apos, AuxP or AuxC
            $self->set_real_deprel($node, 'ExD');
            delete($node->wild()->{'ExD conjuncts'});
        }
    }
}



#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies.
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
        my @children = $node->children();
        my $spanstring = $self->get_node_spanstring($node);
        if($deprel =~ m/^adv\.$/i)
        {
            $deprel = 'Adv';
            $node->set_deprel($deprel);
        }
        if($form eq 'apie' && $deprel eq 'AuxK')
        {
            $deprel = 'AuxP';
            $node->set_deprel($deprel);
        }
        # There is a hyphen marked as conjunct in Jonuskaite_V2-s57.
        if($node->is_punctuation() && $node->is_member() && $deprel eq 'ExD' && $node->is_leaf())
        {
            $node->set_deprel('AuxG');
            $node->set_is_member(undef);
        }
        # Subordinating conjunction wrongly attached as adjunct.
        # kaip už ją atsiskaityta
        if($form eq 'kaip' && $node->is_leaf() && $node->parent()->form() eq 'atsiskaityta')
        {
            my $verb = $node->parent();
            my $comma = $node->get_left_neighbor();
            $comma->set_parent($node);
            $node->set_parent($verb->parent());
            $node->set_deprel('AuxC');
            $verb->set_parent($node);
        }
        # Non-projective comma in pikti_tevai-s45.
        # , ar jau nurimau, kad galėčiau spręsti iškilusią problemą? “,
        # The last comma is attached to "kad", while the question mark and the
        # quotation mark are attached to the first comma, which is the head of
        # coordination.
        if($form eq ',' && $node->ord() == 26  && $node->parent()->ord() == 19 && $node->is_nonprojective())
        {
            if(!$node->parent()->is_root() &&
               !$node->parent()->parent()->is_root() &&
               !$node->parent()->parent()->parent()->is_root() &&
               !$node->parent()->parent()->parent()->parent()->is_root() &&
               $node->parent()->parent()->parent()->parent()->form() eq ',')
            {
                $node->set_parent($node->parent()->parent()->parent()->parent());
            }
        }
        # Nominal predicate (without copula) is a prepositional phrase.
        # Other constituents (Sb, Adv) are wrongly attached to the preposition instead of the noun.
        # Example: Jonuskaite#32 (Jonuskaite-s32)
        # Bet dabar visi kraujo apytakos ratai už kadro.
        # But now all the circulatory circles behind the frame.
        if($form eq 'už' && scalar(@children) > 1)
        {
            my @before = grep {$_->ord() < $node->ord()} (@children);
            my @after = grep {$_->ord() > $node->ord()} (@children);
            # Exclude leading and trailing punctuation from the transformation.
            while(scalar(@before) > 0 && $before[0]->is_punctuation() && $before[0]->deprel() !~ m/^(Coord|Apos)/) {shift(@before)}
            while(scalar(@after) > 0 && $after[-1]->is_punctuation() && $after[-1]->deprel() !~ m/^(Coord|Apos)/) {pop(@after)}
            if(scalar(@after) > 0)
            {
                my $winner = shift(@after);
                foreach my $child (@before, @after)
                {
                    $child->set_parent($winner);
                }
            }
        }
        # In Kuncinas-s70, coordination headed by a comma is attached to a surrounding quotation mark
        # instead of the preposition to which it belongs.
        if(!$node->is_root() && $node->parent()->is_punctuation() && $node->parent()->deprel() !~ m/^(Coord|Apos)/ && !$node->parent()->is_root())
        {
            my $grandparent = $node->parent()->parent();
            $node->set_parent($grandparent);
        }
        # pikti_tevai-s32
        # Kai tėvai priima visus savo jausmus, jiems lengviau apie tai pranešti ir vaikui.
        # When parents accept all their feelings, it is easier for them to communicate this to the child.
        # The deprel of the subordinator "Kai" is wrongly "AuxZ", it should be "AuxC".
        if($spanstring =~ m/^Kai tėvai priima visus savo jausmus/)
        {
            my @subtree = $self->get_node_subtree($node);
            if($subtree[0]->form() eq 'Kai' && $subtree[0]->deprel() eq 'AuxZ')
            {
                $subtree[0]->set_deprel('AuxC');
            }
        }
        # Antanaicio_rec_77s-s3
        # Sąjūdis: nuo „Persitvarkymo “iki Kovo 11-osios, t. 12, d. 1. Vilnius: Baltos lankos, 2008.
        # Large nested coordination of PredNs. My conversion fails when trying to find the subject of the nominal predicate.
        # And it dismantles the coordination. Instead, let us replace all PredNs by Preds, which should be converted reasonably.
        ###!!! This is a temporary hack. It would be better to fix the conversion of PredN!
        if($spanstring =~ m/Sąjūdis.*Persitvarkymo.*Kovo.*osios.*Vilnius.*Baltos lankos.*2008/)
        {
            my @subtree = $self->get_node_subtree($node);
            foreach my $subnode (@subtree)
            {
                if($subnode->deprel() eq 'PredN')
                {
                    $subnode->set_deprel('Pred');
                    log_warn("DEBUG: Sąjūdis: nuo „Persitvarkymo “iki Kovo 11-osios, t. 12, d. 1. Vilnius: Baltos lankos, 2008.");
                }
            }
        }
        # Smulkiojo_ir_vidutinio_verslo_pletros_istatymas-s22
        # 10. Smulkiojo ir vidutinio verslo subjektas – labai maža įmonė, maža įmonė ar vidutinė įmonė, atitinkanti šio įstatymo 3 straipsnyje nustatytas sąlygas, ar verslininkas, atitinkantis šio įstatymo 4 straipsnyje nustatytas sąlygas.
        # 10. "Small and medium-sized enterprise" means a micro, small or medium-sized enterprise fulfilling the conditions laid down in Article 3 of this Law or an entrepreneur meeting the conditions laid down in Article 4 of this Law.
        # The dash after "subjektas" has three children: 10 (Aux), subjektas (Sub), and ar (Coord/PredN_Co).
        # Our heuristics decide to make the dash also Coord but it is not a good idea here, so we should try to prevent it.
        # Beware: After we transform the tree, we will see the same spanstring again when examining the new head, the conjunction "ar".
        # Therefore we must check the node and the spanstring.
        if($form eq '–' && $spanstring =~ m/10.*Smulkiojo ir vidutinio verslo subjektas – labai maža įmonė/)
        {
            my @subtree = $self->get_node_subtree($node);
            ### DEBUGGING
            #my $debug = join('; ', map {$_.':'.$subtree[$_]->form().'<--'.($subtree[$_]->parent()->ord()-1).':'.$subtree[$_]->parent()->form()} (0, 6, 7, 14, 25, 26, 27));
            #log_warn($spanstring);
            #log_warn($debug);
            # Sanity check: did we find what we think we found?
            unless(scalar(@subtree)>=36)
            {
                log_warn("Spanstring = $spanstring");
                my $n = scalar(@subtree);
                log_warn("Subtree has $n nodes.");
            }
            # $subtree[0] je '10'
            # $subtree[7] je pomlčka
            # $subtree[26] je druhe 'ar'
            # $subtree[36] by byla tečka za větou, ale tu jsme zřejmě už dříve posunuli o patro výš
            $subtree[26]->set_parent($subtree[7]->parent());
            $subtree[26]->set_is_member(undef);
            $subtree[7]->set_parent($subtree[26]);
            $subtree[7]->set_deprel('AuxG');
            $subtree[6]->set_parent($subtree[26]);
            $subtree[6]->set_is_member(undef);
            $subtree[0]->set_parent($subtree[26]);
            $subtree[0]->set_deprel('Atr');
            $subtree[0]->set_is_member(undef);
        }
        # Veiklos_ataskaita-s107
        # Buvo aiškinamasi, kokią asmeninę informaciją šios bendrovės renka ir tvarko, ar asmenys yra informuojami apie jų asmens duomenų tvarkymą, ar tinkamai užtikrinama duomenų apsauga ir kt.
        # It was inquired what kind of personal information these companies collect and manage, whether individuals are informed about the processing of their personal data, whether data protection is properly ensured and so on.
        if($form eq 'ir' && $spanstring =~ m/, kokią asmeninę informaciją šios bendrovės renka ir tvarko/)
        {
            # my @subtree = $self->get_node_subtree($node);
            # The phrase is headed by a 'Coord' but it should be 'Coord_Co'.
            $node->set_is_member(1);
        }
        # mok_santr2_91_sak-s49
        # naujausias mokslo žinias ir mokomąją medžiagą
        # the latest scientific knowledge and educational materials
        if($form eq 'ir' && $spanstring =~ m/^naujausias mokslo žinias ir mokomąją medžiagą$/i)
        {
            # In the input data, the conjunction has the deprel 'Aux' instead of 'Coord'.
            # The conjuncts were OK, they had both 'Atr_Co', but in the meantime we may have removed them, seeing that the parent was not 'Coord'.
            $node->set_deprel('Coord');
            my @subtree = $self->get_node_subtree($node);
            $subtree[2]->set_is_member(1);
            $subtree[5]->set_is_member(1);
        }
        # train/Parulskis-2-s29
        # Ko jinai, kalė (rusiškai „suka “), ne į tą pusę važiuoja, klausia manęs vairuotoja.
        # What is she, a bitch (in Russian "suka"), going the wrong way, the driver asks me.
        if($spanstring =~ m/^ko jinai , kalė \( rusiškai „ suka “ \) , ne į tą pusę važiuoja/i)
        {
            my @subtree = $self->get_node_subtree($node);
            $subtree[0]->set_parent($subtree[15]);
            $subtree[1]->set_parent($subtree[15]);
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::LT::Harmonize

Converts Alksnis (Lithuanian Treebank) trees to the style of HamleDT (Prague).
The two annotation styles are very similar, thus only minor changes take place.
Morphological tags are decoded into Interset.

=back

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017, 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
