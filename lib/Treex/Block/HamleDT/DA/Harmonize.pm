package Treex::Block::HamleDT::DA::Harmonize;
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
    default       => 'da::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
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
    # Phrase-based implementation of tree transformations (5.3.2016).
    # Note that Stanford to Prague is not the best model for Danish because the
    # coordination style in the Danish treebank is a hybrid of Stanford and Mel'čuk.
    # But we have currently nothing better.
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # Reattaching final punctuation before solving coordinations saves final punctuation from being treated as coordinational.
    $self->attach_final_punctuation_to_root($root);
    $self->reattach_modifier_from_auxt_to_verb($root);
    $self->check_deprels($root);
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
sub nobj_to_deprel
{
    my $self  = shift;
    my $node = shift;
    my $parent = $node->parent();
    my $ppos = $parent->get_iset('pos');
    $ppos = 'prondet' if($parent->get_iset('prontype') ne '');
    my $deprel;
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
        $deprel = 'Adv';
    }
    elsif ( $node->form() =~ m/^(at|om)$/i && $parent->form() =~ m/^det$/i )
    {
        $deprel = 'Apposition';
    }
    # If there is a determiner it is the head of the noun phrase.
    # The noun that depends on it is tagged 'nobj'. (Adjectives, if any, are tagged 'mod'.)
    elsif($ppos eq 'prondet')
    {
        $deprel = 'DetArg';
    }
    # If there is a numeral substituting the determiner then it is the head.
    elsif ( $ppos eq 'num' )
    {
        $deprel = 'NumArg';
    }
    # If the noun phrase does not contain determiner but it has an adjective, the adjective is the head.
    elsif ( $ppos eq 'adj' )
    {
        $deprel = 'AdjArg';
    }
    # The noun within a prepositional phrase is also tagged 'nobj'.
    # "som" (as) tagged as particle may act as a preposition (Example: som/TT/pobj undskyldning/NN/nobj)
    # "heriblandt" (including) tagged as adverb may act as a preposition (Example: heriblandt/Db/mod Lvov/NN/nobj)
    elsif ($ppos eq 'adp' || lc( $parent->form() ) =~ m/^(.*som|heriblandt)$/)
    {
        $deprel = 'PrepArg';
    }
    # If there is a noun under a subordinating conjunction, it is also tagged 'nobj'.
    # "end" (than) can have noun arguments
    elsif ( $self->is_possible_subordinator($parent) )
    {
        $deprel = 'SubArg';
    }
    # parent is interjection
    # Example: "/XP/pnct Åh/I/qobj snack/NC/nobj ,/XP/pnct "/XP/pnct sagde/VA/ROOT
    elsif ( $ppos eq 'int' )
    {
        $deprel = 'ExD';
    }
    # error in data: sentence-final punctuation, attached to the main verb, has nobj instead of pnct
    elsif ( $node->get_iset('pos') eq 'punc' )
    {
        $node->set_conll_deprel('pnct');
        $deprel = 'AuxK';
    }
    # We need some default so that every nobj gets an deprel even if its parent is another or unknown part of speech.
    # Some examples:
    # Klokken/NN/? 17.05/Cn/nobj
    # §/XS/? 20/AC/nobj
    else
    {
        $deprel = 'Atr';
    }
    return $deprel;
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# http://copenhagen-dependency-treebank.googlecode.com/svn/trunk/manual/cdt-manual.pdf
# (especially the part SYNCOMP in 3.1)
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# There are 40 distinct dependency relation tags in the test data:
# <dobj> <mod> <pred> <subj:pobj> <subj> ROOT aobj appa appr avobj conj coord
# dobj err expl iobj list lobj mod modp name namef namel nobj numm obl part
# pnct pobj possd pred qobj rel subj title tobj vobj voc xpl xtop
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
        my $parent = $node->parent();
        my $ppos   = $parent->get_iset('pos');
        # ROOT ... the main verb of the main clause; head noun if there is no verb
        # list ... the sentence is a list item and this is the main verb attached to the item number
        if ( $deprel =~ m/^(ROOT|list)$/ )
        {
            if ( $node->get_iset('pos') eq 'verb' )
            {
                $node->set_deprel('Pred');
            }
            else
            {
                $node->set_deprel('ExD');
            }
        }

        # part ... verbal particle (e.g. "down" in "break down something")
        elsif ( $deprel eq 'part' )
        {
            $node->set_deprel('AuxT');
        }

        # subj ... subject of clause, attached to the predicate (verb)
        # expl ... expletive (výplňový) subject
        elsif ( $deprel =~ m/^(subj|expl)$/ )
        {
            $node->set_deprel('Sb');
        }

        # dobj ... direct object
        # iobj ... indirect object
        # qobj ... quotation object
        elsif ( $deprel =~ m/^[diq]obj$/ )
        {
            $node->set_deprel('Obj');
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
                $node->set_deprel('Atr');
            }
            else
            {
                $node->set_deprel('Adv');
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
                $node->set_deprel('SubArg');
            }
            elsif ( $ppos eq 'adp' )
            {
                $node->set_deprel('PrepArg');
            }

            # the auxiliary verb form "havde" occurred with unknown tag!
            elsif ( $ppos eq 'verb' || $parent->form() eq 'havde' )
            {
                $node->set_deprel('Obj');
            }
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_deprel('Atr');
            }

            # Example: så længe/Db, ... <clause>/vobj
            elsif ( $ppos eq 'adv' )
            {
                $node->set_deprel('Adv');
            }

            # We need a default here. Sometimes even a frequent word such as the preposition "med" ("with") is tagged as unknown.
            # (On the other hand, it is unclear why specifically this case should have a vobj. The example is from train/004.treex#1.)
            else
            {
                $node->set_deprel('Adv');
            }
        }

        # rel ... relative clause
        elsif ( $deprel eq 'rel' )
        {
            if ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_deprel('Atr');
            }
            elsif ( $ppos eq 'verb' )
            {
                $node->set_deprel('Adv');
            }
            elsif ( $self->is_possible_subordinator($parent) )
            {
                $node->set_deprel('SubArg');
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
                $node->set_deprel('Adv');
            }

            # We need a default for the case that the parent is tagged as another part of speech or unknown word.
            else
            {
                $node->set_deprel('Atr');
            }
        }

        # pred ... predicative (adjective attached to copula)
        elsif ( $deprel eq 'pred' )
        {
            $node->set_deprel('Pnom');
        }

        # nobj ... noun argument of anything but verb?
        elsif ( $deprel eq 'nobj' )
        {
            $node->set_deprel($self->nobj_to_deprel($node));
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
                $node->set_deprel('Atr');
            }

            # numeral parent example:
            # 34 af 149.000 (34 of 149,000)
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_deprel('Atr');
            }
            elsif ( $ppos eq 'verb' )
            {
                $node->set_deprel('Obj');
            }
            elsif ( $ppos eq 'adv' )
            {
                $node->set_deprel('Adv');
            }

            # Preposition attached to another preposition? Example:
            # fra X til Y (from X to Y; "til" is pobj of "fra")
            # If the first preposition governs the second one (like here), the parent (first prep) already has got deprel
            # which we can copy to the child. Note that we probably later want to reattach the child to its grandparent, too.
            elsif ( $ppos eq 'adp' )
            {
                $node->set_deprel( $parent->deprel() );
            }

            # The parent can be an unknown word, e.g. in an English clause embedded in Danish text.
            # Other parts of speech can occur, too, and I do not understand them always, so let's just make this the default.
            else
            {

                # Tokens in foreign phrases in PDT are usually s-tagged 'Atr'.
                $node->set_deprel('Atr');
            }
        }

        # obl ... ???
        # Example:
        # end/J,/pobj af/RR/obl seriøs/AA/mod debat/NN/nobj (than of serious debate)
        elsif ( $deprel eq 'obl' )
        {
            if ( $self->is_possible_subordinator($parent) )
            {
                $node->set_deprel('SubArg');
            }
            elsif ( $ppos eq 'adp' )
            {
                $node->set_deprel('PrepArg');
            }
        }

        # rep ... repetition?
        # Example:
        # Og hvor/rep .../pnct hvordan/mod gik/conj
        elsif ( $deprel eq 'rep' )
        {
            $node->set_deprel('Atr');
        }

        # aobj ... adjectival object
        # poorly documented; example:
        # kan/VB/Pred sige/Vf/vobj sig/P6/dobj fri/AA/aobj for/RR/pobj... (can [verb] himself free for...)
        elsif ( $deprel eq 'aobj' )
        {
            $node->set_deprel('Atv');
        }

        # possd ... argument of a possessive, i.e. the thing possessed
        elsif ( $deprel eq 'possd' )
        {
            $node->set_deprel('PossArg');
        }

        # name ... part of name of a person, e.g. the middle initial, attached to the main name
        # namef ... first name of a person, attached to the last name
        # namel ... last name of a person (attached to another name?)
        # title ... title of a person, attached to the last name
        elsif ( $deprel =~ m/^(name[fl]?|title)$/ )
        {
            $node->set_deprel('Atr');
        }

        # appr ... restrictive apposition (no comma)
        # Example:
        # Socialdemokratiets naestformand Birte Weiss (social democrats' vice-chairman Birte Weiss)
        # "naestformand" is the head, "Weiss" is its appr
        # In PDT, Weiss would be the head and the occupation would be its Atr:
        # americký prezident Bush ("prezident" is Atr of "Bush", "americký" is Atr of "prezident")
        elsif ( $deprel eq 'appr' )
        {
            ###!!! If we later want to make the appr the root of the subtree, we should use a distinctive pseudo-deprel here (NounArg?)
            $node->set_deprel('Atr');
        }

        # appa ... parenthetic apposition
        # Example:
        # Danmarks Socialdemokratiske Ungdom (DSU) (Denmark Social Democratic Union (DSU))
        # "DSU" is appa of "Ungdom"; "(" and ")" are attached to "DSU".
        elsif ( $deprel eq 'appa' )
        {
            ###!!! In PDT the left bracket would be the root of the apposition and both "Ungdom" and "DSU" would be members.
            $node->set_deprel('Apposition');
        }

        # voc ... vocative specification
        # Example:
        # Will you help me, Mary/voc ?
        # In PDT they are tagged ExD_Pa (but since PDT 2.0 the _Pa suffix is not part of the deprel attribute).
        elsif ( $deprel eq 'voc' )
        {
            ###!!! ExD_Pa?
            $node->set_deprel('ExD');
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
                $node->set_deprel('DetArg');
            }
            elsif ( $ppos =~ m/^(noun|adj|num)$/ )
            {
                $node->set_deprel('Atr');
            }
            else
            {
                $node->set_deprel('Adv');
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
            $node->set_deprel('Atr');
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
            $node->set_deprel('Adv');
        }

        # pnct ... punctuation
        elsif ( $deprel eq 'pnct' )
        {
            if ( $node->form() eq ',' )
            {
                $node->set_deprel('AuxX');
            }
            else
            {
                $node->set_deprel('AuxG');
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
            $node->set_deprel('ExD');
        }

        # err ... deprecated error relation
        # Used when connecting two phrases that do not fit together, often because of errors in the text.
        elsif ( $deprel eq 'err' )
        {
            $node->set_deprel('ExD');
        }

        # Pseudo-deprels for coordination nodes until coordination is processed properly.
        # We also duplicate the information in separate temporary attributes that will survive possible deprel modifications.
        # However, the coordination may not be detected if tree topology changes, so we still have to process coordinations ASAP!
        elsif ( $deprel eq 'coord' )
        {
            $node->set_deprel('Coord');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel eq 'conj' )
        {
            $node->set_deprel('CoordArg');
            $node->wild()->{conjunct} = 1;
        }
    }

    # Make sure that all nodes now have their deprels.
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if ( !$deprel )
        {
            $self->log_sentence($root);

            # If the following log is warn, we will be waiting for tons of warinings until we can look at the actual data.
            # If it is fatal however, the current tree will not be saved and we only will be able to examine the original tree.
            log_fatal( "Missing deprel for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }
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
        if(defined($parent) && $parent->deprel() eq 'AuxT')
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
