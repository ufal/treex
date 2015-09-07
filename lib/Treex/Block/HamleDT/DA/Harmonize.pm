package Treex::Block::HamleDT::DA::Harmonize;
use Moose;
use Treex::Core::Common;
use Treex::Core::Cloud;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'da::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

#------------------------------------------------------------------------------
# Reads the Danish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $self->SUPER::process_zone($zone);

    # Adjust the tree structure.
    # Reattaching final punctuation before solving coordinations saves final punctuation from being treated as coordinational.
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    # Shifting afuns at prepositions and subordinating conjunctions must be done after coordinations are solved
    # and with special care at places where prepositions and coordinations interact.
    $self->process_prep_sub_arg_cloud($root);
    $self->lift_noun_phrases($root);
    $self->reattach_modifier_from_auxt_to_verb($root);
    $self->check_afuns($root);
}

#------------------------------------------------------------------------------
# Uses lexical and morphosyntactic information to estimate whether a node can
# function as a subordinator (subordinating conjunction). It does not tell
# whether the node has that function in the current context but the dependency
# relation analyzer can use this method as one tool to tell that.
#------------------------------------------------------------------------------
sub is_possible_subordinator
{
    my $self = shift;
    my $node = shift;

    # Subordinating conjunctions are subordinators.
    # Occasionally conjunctions tagged as coordinating (e.g. "for") work that way too, so we will only check that it is a conjunction.
    return $node->get_iset('pos') =~ m/^(conj|part|adv)$/ ||

        # Some subordinators ("at", "som") are tagged as particles. Some are tagged as adverbs. We list them here.
        # subordinating conjunction: "hvorvidt" (if)
        # WH-adverb functioning as subordinator: "hvordan" (how)
        # "end" (than) can have noun arguments
        $node->form() =~ m/^(at|som)$/;
}

#------------------------------------------------------------------------------
# The dependency tag 'nobj' (noun object) can correspond to many possible
# analytical functions. In some cases it corresponds to pseudo-functions that
# cannot be saved to disk but they will be used to restructure the tree later
# (DetArg, NumArg, AdjArg, PrepArg, SubArg).
#------------------------------------------------------------------------------
sub nobj_to_afun
{
    my $self  = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $ppos = $parent->get_iset('pos');
    $ppos = 'prondet' if($parent->get_iset('prontype') ne '');
    my $afun;
    # Most specific cases (looking at node->form) first!
    # Infinitive can be 'nobj' of another node.
    # så meget kludder ..., at man kan sende... (so much chaotic ..., that one can send...)
    # In this example, "at" is nobj of "så" (often non-projective).
    # In PDT, "at man kan sende" would be Adv clause of "kludder".
    # In another example, the infinitive is 'nobj' of a personal pronoun:
    # Det er ikke sundt at sidde med ... eller ...
    # It is not healthy to sit with ... or ...
    # Here, 'at' is 'nobj' of 'det' (nonprojective).
    if ( $node->form() =~ m/^(at|om)$/i && $parent->form() =~ m/^så$/i )
    {
        $afun = 'Adv';
    }
    elsif ( $node->form() =~ m/^(at|om)$/i && $parent->form() =~ m/^det$/i )
    {
        $afun = 'Apposition';
    }
    # If there is a determiner it is the head of the noun phrase.
    # The noun that depends on it is tagged 'nobj'. (Adjectives, if any, are tagged 'mod'.)
    elsif($ppos eq 'prondet')
    {
        $afun = 'DetArg';
    }
    # If there is a numeral substituting the determiner then it is the head.
    elsif ( $ppos eq 'num' )
    {
        $afun = 'NumArg';
    }
    # If the noun phrase does not contain determiner but it has an adjective, the adjective is the head.
    elsif ( $ppos eq 'adj' )
    {
        $afun = 'AdjArg';
    }
    # The noun within a prepositional phrase is also tagged 'nobj'.
    # "som" (as) tagged as particle may act as a preposition (Example: som/TT/pobj undskyldning/NN/nobj)
    # "heriblandt" (including) tagged as adverb may act as a preposition (Example: heriblandt/Db/mod Lvov/NN/nobj)
    elsif ($ppos eq 'adp' || lc( $parent->form() ) =~ m/^(.*som|heriblandt)$/)
    {
        $afun = 'PrepArg';
    }
    # If there is a noun under a subordinating conjunction, it is also tagged 'nobj'.
    # "end" (than) can have noun arguments
    elsif ( $self->is_possible_subordinator($parent) )
    {
        $afun = 'SubArg';
    }
    # parent is interjection
    # Example: "/XP/pnct Åh/I/qobj snack/NC/nobj ,/XP/pnct "/XP/pnct sagde/VA/ROOT
    elsif ( $ppos eq 'int' )
    {
        $afun = 'ExD';
    }
    # error in data: sentence-final punctuation, attached to the main verb, has nobj instead of pnct
    elsif ( $node->get_iset('pos') eq 'punc' )
    {
        $node->set_conll_deprel('pnct');
        $afun = 'AuxK';
    }
    # We need some default so that every nobj gets an afun even if its parent is another or unknown part of speech.
    # Some examples:
    # Klokken/NN/? 17.05/Cn/nobj
    # §/XS/? 20/AC/nobj
    else
    {
        $afun = 'Atr';
    }
    return $afun;
}

#------------------------------------------------------------------------------
# Try to convert dependency relation tags to analytical functions.
# http://copenhagen-dependency-treebank.googlecode.com/svn/trunk/manual/cdt-manual.pdf
# (especially the part SYNCOMP in 3.1)
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# There are 40 distinct dependency relation tags in the test data:
# <dobj> <mod> <pred> <subj:pobj> <subj> ROOT aobj appa appr avobj conj coord
# dobj err expl iobj list lobj mod modp name namef namel nobj numm obl part
# pnct pobj possd pred qobj rel subj title tobj vobj voc xpl xtop
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');

        # ROOT ... the main verb of the main clause; head noun if there is no verb
        # list ... the sentence is a list item and this is the main verb attached to the item number
        if ( $deprel =~ m/^(ROOT|list)$/ )
        {
            if ( $node->get_iset('pos') eq 'verb' )
            {
                $node->set_afun('Pred');
            }
            else
            {
                $node->set_afun('ExD');
            }
        }

        # part ... verbal particle (e.g. "down" in "break down something")
        elsif ( $deprel eq 'part' )
        {
            $node->set_afun('AuxT');
        }

        # subj ... subject of clause, attached to the predicate (verb)
        # expl ... expletive (výplňový) subject
        elsif ( $deprel =~ m/^(subj|expl)$/ )
        {
            $node->set_afun('Sb');
        }

        # dobj ... direct object
        # iobj ... indirect object
        # qobj ... quotation object
        elsif ( $deprel =~ m/^[diq]obj$/ )
        {
            $node->set_afun('Obj');
        }

        # lobj ... valency-bound location/direction adverbial?
        # Examples:
        # Ruslands vej _til demokrati_
        # gaar/verb _gennem diktatur_
        # tobj ... valency-bound time adverbial?
        # avobj ... adverbial object (Example: She acted out of love.)
        elsif ( $deprel =~ m/^([lt]|av)obj$/ )
        {
            if ( $ppos eq 'noun' )
            {
                $node->set_afun('Atr');
            }
            else
            {
                $node->set_afun('Adv');
            }
        }

        # vobj ... verbal argument
        # Example: til/RR at/TT gaa/Vf/vobj (until going)
        # under a subordinator: SubArg
        # under a preposition (! - it seems that constructions like "without going" can use a finite form of the verb "to go"): PrepArg
        # under a verb: modal or other verbal construction (Obj)
        elsif ( $deprel eq 'vobj' )
        {

            # Subordinating conjunctions.
            # "at" and "som" can be tagged as particle or subordinating conjunction.
            # "for" occurs tagged as coordinating conjunction, although it functions as subordinator.
            if ( $self->is_possible_subordinator($parent) )
            {
                $node->set_afun('SubArg');
            }
            elsif ( $ppos eq 'adp' )
            {
                $node->set_afun('PrepArg');
            }

            # the auxiliary verb form "havde" occurred with unknown tag!
            elsif ( $ppos eq 'verb' || $parent->form() eq 'havde' )
            {
                $node->set_afun('Obj');
            }
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_afun('Atr');
            }

            # Example: så længe/Db, ... <clause>/vobj
            elsif ( $ppos eq 'adv' )
            {
                $node->set_afun('Adv');
            }

            # We need a default here. Sometimes even a frequent word such as the preposition "med" ("with") is tagged as unknown.
            # (On the other hand, it is unclear why specifically this case should have a vobj. The example is from train/004.treex#1.)
            else
            {
                $node->set_afun('Adv');
            }
        }

        # rel ... relative clause
        elsif ( $deprel eq 'rel' )
        {
            if ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_afun('Atr');
            }
            elsif ( $ppos eq 'verb' )
            {
                $node->set_afun('Adv');
            }
            elsif ( $self->is_possible_subordinator($parent) )
            {
                $node->set_afun('SubArg');
            }

            # Relative pronouns and determiners are possible subordinators in DDT and the relative clause predicates are attached to them.
            # In PDT they would be normal nodes in the relative clause, possibly filling valency slots of the predicate that would be the root of the clause.
            # When the relative pronoun is governed by a preposition in DDT the predicate is also attached to the preposition.
            # Example (train/003.treex#108):
            # , i/nobj hvilken/nobj grad/nobj Folketinget/subj er/rel indblandet/vobj (to what degree the Folketing is involved)
            elsif ( $ppos eq 'adp' )
            {
                ###!!! We should investigate whether the clause modifies a noun (Atr) or a verb (Adv or Obj).
                ###!!! We should also later restructure this part.
                $node->set_afun('Adv');
            }

            # We need a default for the case that the parent is tagged as another part of speech or unknown word.
            else
            {
                $node->set_afun('Atr');
            }
        }

        # pred ... predicative (adjective attached to copula)
        elsif ( $deprel eq 'pred' )
        {
            $node->set_afun('Pnom');
        }

        # nobj ... noun argument of anything but verb?
        elsif ( $deprel eq 'nobj' )
        {
            $node->set_afun($self->nobj_to_afun($node));
        }

        # pobj ... prepositional object
        # Example: i en _af_ deres artikler (in one of these articles)
        # "en" is tagged as indefinite determiner but unlike other cases, here we do not want to lift its argument!
        elsif ( $deprel eq 'pobj' )
        {
            if (lc( $parent->form() ) eq 'en'
                &&
                lc( $node->form() ) eq 'af'
                )
            {
                $node->set_afun('Atr');
            }

            # numeral parent example:
            # 34 af 149.000 (34 of 149,000)
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_afun('Atr');
            }
            elsif ( $ppos eq 'verb' )
            {
                $node->set_afun('Obj');
            }
            elsif ( $ppos eq 'adv' )
            {
                $node->set_afun('Adv');
            }

            # Preposition attached to another preposition? Example:
            # fra X til Y (from X to Y; "til" is pobj of "fra")
            # If the first preposition governs the second one (like here), the parent (first prep) already has got afun
            # which we can copy to the child. Note that we probably later want to reattach the child to its grandparent, too.
            elsif ( $ppos eq 'adp' )
            {
                $node->set_afun( $parent->afun() );
            }

            # The parent can be an unknown word, e.g. in an English clause embedded in Danish text.
            # Other parts of speech can occur, too, and I do not understand them always, so let's just make this the default.
            else
            {

                # Tokens in foreign phrases in PDT are usually s-tagged 'Atr'.
                $node->set_afun('Atr');
            }
        }

        # obl ... ???
        # Example:
        # end/J,/pobj af/RR/obl seriøs/AA/mod debat/NN/nobj (than of serious debate)
        elsif ( $deprel eq 'obl' )
        {
            if ( $self->is_possible_subordinator($parent) )
            {
                $node->set_afun('SubArg');
            }
            elsif ( $ppos eq 'adp' )
            {
                $node->set_afun('PrepArg');
            }
        }

        # rep ... repetition?
        # Example:
        # Og hvor/rep .../pnct hvordan/mod gik/conj
        elsif ( $deprel eq 'rep' )
        {
            $node->set_afun('Atr');
        }

        # aobj ... adjectival object
        # poorly documented; example:
        # kan/VB/Pred sige/Vf/vobj sig/P6/dobj fri/AA/aobj for/RR/pobj... (can [verb] himself free for...)
        elsif ( $deprel eq 'aobj' )
        {
            $node->set_afun('Atv');
        }

        # possd ... argument of a possessive, i.e. the thing possessed
        elsif ( $deprel eq 'possd' )
        {
            $node->set_afun('PossArg');
        }

        # name ... part of name of a person, e.g. the middle initial, attached to the main name
        # namef ... first name of a person, attached to the last name
        # namel ... last name of a person (attached to another name?)
        # title ... title of a person, attached to the last name
        elsif ( $deprel =~ m/^(name[fl]?|title)$/ )
        {
            $node->set_afun('Atr');
        }

        # appr ... restrictive apposition (no comma)
        # Example:
        # Socialdemokratiets naestformand Birte Weiss (social democrats' vice-chairman Birte Weiss)
        # "naestformand" is the head, "Weiss" is its appr
        # In PDT, Weiss would be the head and the occupation would be its Atr:
        # americký prezident Bush ("prezident" is Atr of "Bush", "americký" is Atr of "prezident")
        elsif ( $deprel eq 'appr' )
        {
            ###!!! If we later want to make the appr the root of the subtree, we should use a distinctive pseudo-afun here (NounArg?)
            $node->set_afun('Atr');
        }

        # appa ... parenthetic apposition
        # Example:
        # Danmarks Socialdemokratiske Ungdom (DSU) (Denmark Social Democratic Union (DSU))
        # "DSU" is appa of "Ungdom"; "(" and ")" are attached to "DSU".
        elsif ( $deprel eq 'appa' )
        {
            ###!!! In PDT the left bracket would be the root of the apposition and both "Ungdom" and "DSU" would be members.
            $node->set_afun('Apposition');
        }

        # voc ... vocative specification
        # Example:
        # Will you help me, Mary/voc ?
        # In PDT they are tagged ExD_Pa (but since PDT 2.0 the _Pa suffix is not part of the afun attribute).
        elsif ( $deprel eq 'voc' )
        {
            ###!!! ExD_Pa?
            $node->set_afun('ExD');
        }

        # mod ... attribute of a noun
        # mod ... adverbial modifier of a verb
        # mod ... adjective attached to determiner
        # xpl ... explication of an NP or VP
        # Example:
        # The title of the plan: "The Virtuous Circle".
        # modo ... deprecated name for object-oriented modifier
        # modp ... deprecated name for parenthetic modifier
        # modr ... deprecated name for restrictive modifier
        # mods ... deprecated name for ??? modifier
        elsif ( $deprel =~ m/^(mod[oprs]?|xpl)$/ )
        {
            # If there are noun siblings then this adjective will not become the new head and thus it is not the DetArg.
            if ( $node->get_iset('pos') eq 'adj' &&
                 $parent->get_iset('prontype') ne '' &&
                 !grep {$_->get_iset('pos') eq 'noun'} ($node->get_siblings()))
            {
                $node->set_afun('DetArg');
            }
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_afun('Atr');
            }
            else
            {
                $node->set_afun('Adv');
            }
        }

        # numa ... additive numeral complement
        # numm ... multiplicative numeral complement
        # Numerals license one additive and one numeral complement, both optional. The numerical value
        # associated with the expression is the value M * N + A, where M is the numerical value of the
        # multiplicative complement, A is the numerical value of the additive complement, and N is
        # the numerical value associated with the lexical numeral itself. Eg, "two hundred four" has
        # value "2 * 100 + 4", "two hundred four thousand" has value "(2 * 100 + 4) * 1000", and "two
        # hundred four thousand and twenty three" has value "(2 * 100 + 4) * 1000 + (20 + (3))".
        elsif ( $deprel =~ m/^num[am]$/ )
        {
            $node->set_afun('Atr');
        }

        # xtop ... external topic with resuming pronoun
        # "An external topic is a sentence-initial NP whose only function is to
        # provide the antecedent for a pronoun later in the sentence. Eg in "John,
        # he is a nice person". Here "John" is the "xtop" of "is", and "he" is the subject of "is"."
        elsif ( $deprel eq 'xtop' )
        {

            # Example from the Danish data:
            # Og når deres repraesentanter er parate ..., så stopper en jernnaeve det.
            # naar/J,/xtop governs the subordinated clause and is attached to the predicate of the main clause (stopper).
            # saa/Db/mod is the co-coordinator and is attached to the predicate of the main clause, too.
            # I am currently not sure how to map this on the PDT rules.
            $node->set_afun('Adv');
        }

        # pnct ... punctuation
        elsif ( $deprel eq 'pnct' )
        {
            if ( $node->form() eq ',' )
            {
                $node->set_afun('AuxX');
            }
            else
            {
                $node->set_afun('AuxG');
            }

            # The sentence-final punctuation should get 'AuxK' but we will also have to reattach it and we will retag it at the same time.
        }

        # <dobj> <mod> <pred> <subj:pobj> <subj>
        # Tags in angle brackets are used with elliptical coordinations:
        # "On Monday he bought a house and yesterday [he bought] a car."
        # "yesterday" and "a car" should be attached to the second "bought".
        # Since it is missing, they will be attached directly to the coordinator.
        # The tag still reflects their relation to the missing node.
        # In PDT, we tag them 'ExD' instead.
        elsif ( $deprel =~ m/^<.+>$/ )
        {
            $node->set_afun('ExD');
        }

        # err ... deprecated error relation
        # Used when connecting two phrases that do not fit together, often because of errors in the text.
        elsif ( $deprel eq 'err' )
        {
            $node->set_afun('ExD');
        }

        # Pseudo-afuns for coordination nodes until coordination is processed properly.
        # We also duplicate the information in separate temporary attributes that will survive possible afun modifications.
        # However, the coordination may not be detected if tree topology changes, so we still have to process coordinations ASAP!
        elsif ( $deprel eq 'coord' )
        {
            $node->set_afun('Coord');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel eq 'conj' )
        {
            $node->set_afun('CoordArg');
            $node->wild()->{conjunct} = 1;
        }
    }

    # Make sure that all nodes now have their afuns.
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( !$afun )
        {
            $self->log_sentence($root);

            # If the following log is warn, we will be waiting for tons of warinings until we can look at the actual data.
            # If it is fatal however, the current tree will not be saved and we only will be able to examine the original tree.
            log_fatal( "Missing afun for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }
}

#------------------------------------------------------------------------------
# Swaps nodes at some edges where the Danish notion of dependency violates the
# principle of reducibility: nouns attached to determiners, numbers etc.
#------------------------------------------------------------------------------
sub lift_noun_phrases
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( $afun =~ m/^(DetArg|NumArg|PossArg|AdjArg)$/ )
        {
            $self->lift_node( $node, 'Atr' );
        }
    }
}

#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Danish
# treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_mosford($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_orphans();
    push(@recurse, $coordination->get_children());
    return @recurse;
}

#------------------------------------------------------------------------------
# Corrects attachment of adverbial modifier that is erroneously attached to
# a verbal particle instead of the verb. (There is one occurrence of the error
# in the treebank.)
#------------------------------------------------------------------------------
sub reattach_modifier_from_auxt_to_verb
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        if(defined($parent) && $parent->afun() eq 'AuxT')
        {
            my $grandparent = $parent->parent();
            if(defined($grandparent) && $grandparent->match_iset('pos' => 'verb'))
            {
                $node->set_parent($grandparent);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::DA::Harmonize

Converts trees coming from Danish Dependency Treebank via the CoNLL-X format to the style of
the Prague Dependency Treebank. Converts tags and restructures the tree.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
