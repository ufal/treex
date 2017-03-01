package Treex::Block::HamleDT::NL::Harmonize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::AlpinoToPrague;
extends 'Treex::Block::HamleDT::Harmonize';



has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'nl::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Dutch tree, converts morphosyntactic tags to Interset, converts
# dependency relations, transforms tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $self->SUPER::process_zone( $zone );
    # Phrase-based implementation of tree transformations (22.1.2016).
    my $builder = new Treex::Tool::PhraseBuilder::AlpinoToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # Unfortunately the phrase builder fails to convert all SubArg nodes and we must get rid of this relation before we declare the tree to be Prague style.
    foreach my $node ($root->get_descendants())
    {
        if($node->deprel() eq 'SubArg')
        {
            $node->set_deprel('Adv');
        }
    }
    $self->attach_final_punctuation_to_root($root);
    # Fix interrogative pronouns before subordinating conjunctions because the treebank wants us to think they are the same.
    $self->fix_int_rel_words($root);
    $self->fix_int_rel_prepositional_phrases($root);
    $self->fix_int_rel_phrases($root);
    $self->fix_naar_toe($root);
    $self->fix_als($root);
    $self->lift_commas($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels.
# acroread /net/data/conll/2006/nl/doc/syn_prot.pdf &
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # The corpus contains the following 26 dependency relation tags:
        # ROOT app body cnj crd det dp hd hdf ld me mod obcomp obj1 obj2
        # pc pobj1 predc predm punct sat se su sup svp vc
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
            ###!!! If the root is conjunction we ought to check whether it conjoins verbs or something else!
            if ( $pos eq 'verb' || $pos eq 'conj' )
            {
                $deprel = 'Pred';
            }
            else
            {
                $deprel = 'ExD';
            }
        }

        # Apposition.
        elsif ( $deprel eq 'app' )
        {
            $deprel = 'Apposition';
        }

        # Predicate of subordinated clause.
        elsif ( $deprel eq 'body' )
        {
            # Instead of subordinating conjunction there may be a relative pronoun.
            ###!!! But then we may want to reattach the pronoun instead of labeling it AuxC!
            # It may also be an infinitive under a preposition (train/001#9: 'te raden' = 'to recommend').
            # Sometimes the infinitival 'te' is not tagged as preposition but as adverb.
            # Sometimes there is 'van', tagged as preposition or adverb.
            ###!!! Since the annotators put the relative element always above the verb and since it can also be an attribute of a noun, the parent can be a noun.
            ###!!! Example (train/001#303):
            ###!!! welke boeken jij leest laat   me koud
            ###!!! what  books  you read  leaves me cold
            ###!!! boeken/su ( welke/det , leest/body )
            ###!!! Similarly, the parent can be adjective ('hoe snel' = 'how fast'; 'snel' is the adjectival parent) or adverb ('hoe vaak' = 'how often').
            ###!!! Occasionally it can be a participle functioning as a noun ('hoeveel politieke gevangenen' = 'how many political prisoners').
            ###!!! It can also be a numeral ('hoeveel' = 'how many'; 'miljoen' in 'hoeveel miljoen Joden' = 'how many million Jews').
            ###!!! It can be a coordinating conjunction if the parent is coordination ('welke architect en meubelmaker' = 'which architect and furniture maker').
            if ( !$parent->is_root() )
            {
                $deprel = 'SubArg';
            }
            else
            {
                $self->log_sentence($node);
                log_warn('I do not know what to do with the label "body" when its parent is the root.');
                $deprel = 'NR';
            }
        }

        # Conjunct.
        elsif ( $deprel eq 'cnj' )
        {
            $deprel = 'CoordArg';
            $node->wild()->{conjunct} = 1;
        }

        # Additional coordinating conjunction that does not govern coordination.
        # Example (test/001#54):
        # zowel in lengte als      gewicht
        # as    in length as  [in] weight
        # "zowel" is the head, its deprel is the relation to the parent of the coordination.
        # Children of "zowel": in/cnj als/crd gewicht/cnj
        elsif ( $deprel eq 'crd' )
        {
            $deprel = 'AuxY';
        }

        # Determiner (article, number etc.)
        elsif ( $deprel eq 'det' )
        {
            $deprel = 'Atr';
        }

        # Sort of parenthesis? There is only one occurrence of this label in the whole treebank: train/025#330.
        elsif ( $deprel eq 'dp' )
        {
            ###!!! How do we currently tag parenthesized insertions in PDT? # could be Apposition?
            $deprel = 'Adv';
        }

        # Unknown meaning, very infrequent (9 occurrences). Example train/001#232: one instance of verb 'moet' ('must') attached to another.
        # Documentation page 8 Section 2.1.1: HD = werkwoordelijk hoofd finiet of niet-finiet (verbal head finite or non-finite).
        elsif ( $deprel eq 'hd' )
        {
            ###!!! Are the other occurrences similar? Look at the other examples!
            ###!!! Is there a better label?
            $deprel = 'AuxV';
        }

        # Non-head part of compound preposition? Example test/001#19: 'tot nu toe' = 'up to now' (lit. 'to now up')
        # 'toe' in 'naar toe': 'naar' means 'to', 'towards', and is tagged as adverb.
        # 'toe' [tu] is a postposition, cf. English 'to' and German 'zu'.
        # 'naar toe' and 'naartoe' together also means 'to', 'towards'. The whole thing also seems to behave as postposition.
        # Example: ", waar men de patienten naar toe schuift" = "where one pushes the patients to"
        ###!!! At least we could make 'naar' depend on 'toe', 'toe' being AuxP and 'naar' being Adv.
        elsif ( $deprel eq 'hdf' )
        {
            $deprel = 'AuxP';
        }

        # locative or directional complement
        # locatief of directioneel complement
        # Example (test/001#6): 'om de tafel zitten' = 'to sit around the table'
        elsif ( $deprel eq 'ld' )
        {
            $deprel = 'Adv';
        }

        # maat (duur, gewicht...) complement
        # measure (length, weight...) complement
        # Example (test/001#85): 'vier dagen' = 'four days'
        elsif ( $deprel eq 'me' )
        {
            $deprel = 'Adv';
        }

        # bijwoordelijke bepaling
        # adverbial
        # JM: it seems this label is also used for noun modifier (i.e. as our Atr)
        elsif ( $deprel eq 'mod' )
        {
            if ($ppos eq 'noun')
            {
                $deprel = 'Atr';
            }
            elsif ($node->form() =~ m/^niet$/i)
            {
                $deprel = 'Neg';
            }
            else
            {
                $deprel = 'Adv';
            }
        }

        # obcomp
        # Example (test/001#17): 'zo mogelijk veel' = lit. 'so possible much' = 'as much as possible'
        # veel ( zo/mod ( mogelijk/obcomp ) )
        elsif ( $deprel eq 'obcomp' )
        {
            $deprel = 'Adv';
        }

        # obj1:
        # lijdend voorwerp
        # direct object
        # pobj1:
        # voorlopig direct object
        # provisional direct object (???)
        # Both may appear attached to a preposition, which requires special treatment.
        elsif ( $deprel =~ m/^p?obj1$/ )
        {
            if ( $ppos eq 'adp' )
            {
                $deprel = 'PrepArg';
            }
            else
            {
                $deprel = 'Obj';
            }
        }

        # secundair object (meewerkend, belanghebbend, ondervindend)
        # secondary object (cooperative, interested, empirical)
        elsif ( $deprel eq 'obj2' )
        {
            $deprel = 'Obj';
        }

        # voorzetselvoorwerp
        # prepositional object
        # This is the relation of the prepositional phrase to its parent.
        # The relation of the inner noun phrase to the preposition is obj1.
        elsif ( $deprel eq 'pc' )
        {
            $deprel = 'Obj';
        }

        # predicatief complement
        # predicative complement
        elsif ( $deprel eq 'predc' )
        {
            $deprel = 'Pnom';
        }

        # bepaling van gesteldheid 'tijdens de handeling'
        # provision of state 'during the act'
        # Example (train/001#18): 'alleen samen met het veld' = 'only together with the field'
        # The phrase depends as predm on a modal verb. Non-projectively because it lies between modifiers of the infinitive.
        elsif ( $deprel eq 'predm' )
        {
            ###!!! Is it always adverbial? Investigate the other examples!
            $deprel = 'Adv';
        }

        # punctuation
        elsif ( $deprel eq 'punct' )
        {
            if ( $node->form() eq ',' )
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }

        # Only one occurrence in the whole treebank (train/017#279)
        elsif ( $deprel eq 'sat' )
        {
            $deprel = 'Adv';
        }

        # verplicht reflexief object
        # obligatory reflexive object
        # Example (test/001#122): 'ontwikkelt zich' = lit. 'develops itself' = 'develops'
        elsif ( $deprel eq 'se' )
        {
            $deprel = 'AuxT';
        }

        # onderwerp
        # subject
        elsif ( $deprel eq 'su' )
        {
            $deprel = 'Sb';
        }

        # voorlopig subject
        # provisional subject (???)
        # Example (test/001#25): 'het ligt in de...' = 'it lies in the...'
        elsif ( $deprel eq 'sup' )
        {
            $deprel = 'Sb';
        }

        # scheidbaar deel van werkwoord
        # separable part of verb (not just separable prefixes as in german: also parts of light verb constructions?)
        # Example (test/001#4): 'zorg' in 'zorg dragen' = 'ensure'
        elsif ( $deprel eq 'svp' )
        {
            $deprel = 'AuxT';
        }

        # verbaal complement, werkwoordelijk deel van gezegde
        # verbal complement, verbal part of the said
        # Example (test/001#2): participle 'gekozen' in 'is gekozen' = 'is selected'
        elsif ( $deprel eq 'vc' )
        {
            # We want to make the participle the head and the auxiliary verb its AuxV dependent.
            if($node->is_participle() && $parent->lemma() eq 'heb')
            {
                $deprel = 'AuxArg';
            }
            # The 'vc' label is also used for infinitive attached to a modal verb.
            elsif($node->is_infinitive() && $parent->is_modal())
            {
                $deprel = 'Obj';
            }
            # The 'vc' label is also used for complement subordinate clauses. Their head in Alpino is either
            # a subordinating conjunction (complementizer), or a relative word (pronoun, determiner, adverb).
            elsif(!$node->is_verb())
            {
                # A subordinating conjunction will be later relabeled to AuxC and this label will be pushed down to the predicate of the complement clause.
                $deprel = 'Obj';
            }
            else
            {
                $deprel = 'AuxV';
            }
        }

        else
        {
            $deprel = 'NR';
        }

        $node->set_deprel($deprel);
        if ( $node->wild()->{conjunct} && $node->wild()->{coordinator} )
        {
            log_warn('We do not expect a node to be conjunct and coordination at the same time.');
        }
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
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $parent = $node->parent();
        my @children = $node->children();
        if($node->form() eq '!!!' && $node->is_verb())
        {
            $node->iset()->set('pos' => 'punc');
        }
        # het diertje, een_maand_of vier oud, bezweek
        # the animal, four months old, died
        # The numeric part (een_maand_of vier) is attached to the previous comma, which is a bug.
        elsif(defined($parent) && defined($parent->form()) && defined($node->form()) &&
           $parent->form() eq ',' && $node->form() eq 'vier' &&
           $i<$#nodes && defined($nodes[$i+1]->form()) && $nodes[$i+1]->form() eq 'oud' &&
           !$nodes[$i+1]->is_descendant_of($node))
        {
            $node->set_parent($nodes[$i+1]);
            $parent->set_parent($nodes[$i+1]);
        }
    }
}



#------------------------------------------------------------------------------
# Reattaches interrogative and relative pronouns and adverbs. The predicate of
# the clause they introduce is originally attached to the pronoun, as if it was
# a subordinating conjunction. However, in contrast to conjunctions, pronouns
# and adverbs typically also complement or modify the verb, so we want them to
# be attached there.
# It is not easy to tell what is the relation of the interrogative word towards
# the predicate: Sb, Obj, or Adv?
#------------------------------------------------------------------------------
sub fix_int_rel_words
{
    my $self = shift;
    my $root = shift;
    # The construction can appear directly under root (interrogative sentences)
    # or elswhere in the sentence (usually relative clauses).
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # We are looking for a node that
        # - is an interrogative or relative pronoun (e.g. "wie" = "who", "wat" = "what") or adverb ("waar" = "where", "hoe" = "how");
        # - has just one child, which is a verb, its deprel is "body" and deprel is "SubArg";
        my @children = $node->children();
        if($node->get_iset('prontype') =~ m/^(int|rel)$/ && $node->form() =~ m/^(wie|wat|waar|hoe)$/i &&
           scalar(@children)==1)
        {
            my $gc = $children[0];
            if($gc->get_iset('pos') eq 'verb' && $gc->deprel() eq 'SubArg')
            {
                my $pronoun = $node;
                my $verb = $gc;
                # Attach the verb to the parent of the pronoun.
                # Attach the pronoun to the verb.
                # Use heuristics to estimate the function of the pronoun.
                $verb->set_parent($pronoun->parent());
                $verb->set_deprel($pronoun->deprel());
                $verb->set_is_member($pronoun->is_member());
                $pronoun->set_parent($verb);
                $pronoun->set_is_member(0);
                # If there is an adverb instead of a pronoun, it is adverbial modifier.
                # If there is no subject, this could be a subject.
                # If there is a subject and the verb is a form of "to be", this could be a nominal predicate.
                # Otherwise this is an object.
                if($pronoun->get_iset('pos') eq 'adv')
                {
                    $pronoun->set_deprel('Adv');
                }
                elsif(!defined($self->get_subject($verb)))
                {
                    $pronoun->set_deprel('Sb');
                }
                elsif($verb->lemma() =~ m/^(ben|word)$/) # to be | to become
                {
                    $pronoun->set_deprel('Pnom');
                }
                else
                {
                    $pronoun->set_deprel('Obj');
                }
                # If the pronoun was attached directly to the root, it had the 'ExD' deprel.
                # However, if there is now a verb instead, it can be a 'Pred'.
                if($verb->parent()->is_root() && $verb->deprel() eq 'ExD')
                {
                    $verb->set_deprel('Pred');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Identifies and reattaches interrogative or relative prepositional phrases.
# This is a more complicated instance of the problem solved by the previous
# method. Example: "Over welk gas gaat het?" = "About which gas is it?"
# This method must be called before PrepArgs and SubArgs are transformed to
# AuxP and AuxC respectively, because it relies on the values of Prep/SubArg.
#------------------------------------------------------------------------------
sub fix_int_rel_prepositional_phrases
{
    my $self = shift;
    my $root = shift;
    # The construction can appear directly under root (interrogative sentences)
    # or elswhere in the sentence (usually relative clauses).
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # We are looking for a node that
        # - is a preposition;
        # - has two children;
        # - the first child is PrepArg and its subtree contains an interrogative or relative word;
        # - the second child is SubArg and verb;
        if($node->get_iset('pos') eq 'prep')
        {
            my @children = $node->children();
            if(scalar(@children)==2 && $children[0]->deprel() eq 'PrepArg' && $children[1]->deprel() eq 'SubArg')
            {
                my $preposition = $node;
                my $verb = $children[1];
                $verb->set_parent($preposition->parent());
                $verb->set_deprel($preposition->deprel());
                $verb->set_is_member($preposition->is_member());
                $preposition->set_parent($verb);
                # Use heuristics to estimate the function of the prepositional phrase.
                # Subject or nominal predicate are not likely. Object or adverbial modifier are much more probable.
                # It is difficult to distinguish between the two. Let's pick the object.
                $preposition->set_deprel('Obj');
                $preposition->set_is_member(0);
                # If the preposition was attached directly to the root, it had the 'ExD' deprel.
                # However, if there is now a verb instead, it can be a 'Pred'.
                # Let's first check that it really is a verb.
                if($verb->get_iset('pos') eq 'verb' && $verb->parent()->is_root() && $verb->deprel() eq 'ExD')
                {
                    $verb->set_deprel('Pred');
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Another instance of the interrogative and relative phrases: no preposition,
# still the interrogative word is hidden deep in the subtree, and even a
# coordination is involved:
# Welke Nederlandse architect en meubelmaker was .../Pnom
# Which Dutch architect and furniture designer was .../Pnom
# Symptoms: The verb ("was") is a SubArg and it has left siblings. (The fact
# that the siblings may be conjuncts rather than dependents poses no problem
# here.) The first word of the sibling subtree(s) is interrogative or relative.
# (Here, "welke" has the feature prontype=int.) We are not going to check this
# but it really ought to be the first word. It would not be the first word if
# there was a preposition but we have addressed prepositional phrases
# separately.
# Solution: Make the current parent of the verb with all the siblings depend on
# the verb. Use heuristics to estimate its function.
#------------------------------------------------------------------------------
sub fix_int_rel_phrases
{
    my $self = shift;
    my $root = shift;
    # The construction can appear directly under root (interrogative sentences)
    # or elswhere in the sentence (usually relative clauses).
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # We are looking for a node that
        # - has two or more children;
        # - the last child is not a conjunct and is SubArg;
        my @children = $node->children();
        if(scalar(@children)>=2 && $children[-1]->get_real_afun() eq 'SubArg' && !$children[-1]->is_member())
        {
            my $verb = $children[-1];
            $verb->set_parent($node->parent());
            # If the node was attached directly to the root, it had the 'ExD' deprel.
            # If it was head of coordination, it had 'Coord' instead.
            # However, if there is now a verb instead, it can be a 'Pred'.
            if($verb->parent()->is_root())
            {
                $verb->set_real_afun('Pred');
            }
            else
            {
                $verb->set_real_afun($node->get_real_afun());
            }
            $verb->set_is_member($node->is_member());
            $node->set_parent($verb);
            $node->set_is_member(0);
            # Use heuristics to estimate the function of the prepositional phrase.
            # If there is no subject, this could be a subject.
            # If there is a subject and the verb is a form of "to be", this could be a nominal predicate.
            # Otherwise this is an object.
            if(!defined($self->get_subject($verb)))
            {
                $node->set_real_afun('Sb');
            }
            elsif($verb->lemma() =~ m/^(ben|word)$/) # to be | to become
            {
                $node->set_real_afun('Pnom');
            }
            else
            {
                $node->set_real_afun('Obj');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns reference to the node acting as the subject of a given verb. Returns
# undef if there is no subject. Searches verbal children in case of compound
# verb forms. For instance, in "wat wil jij worden" ("what will you become"),
# "jij" is the subject of "wil worden" but it is attached to "worden" and thus
# it is not directly visible among the children of "wil".
#------------------------------------------------------------------------------
sub get_subject
{
    my $self = shift;
    my $verb = shift;
    my @subjects = grep {$_->deprel() eq 'Sb'} ($verb->children());
    my $subject;
    if(@subjects)
    {
        $subject = $subjects[0];
    }
    else
    {
        my @auxv = grep {$_->deprel() eq 'AuxV'} ($verb->children());
        foreach my $auxv (@auxv)
        {
            $subject = $self->get_subject($auxv);
            last if(defined($subject));
        }
    }
    return $subject;
}



#------------------------------------------------------------------------------
# Reverses dependency direction in the phrase "naar toe". The word "naar" is
# tagged as adverb and it means "to", "towards", "in the direction". The
# meaning of the whole phrase "naar toe" (sometimes written as one word
# "naartoe") seems to be more or less the same. Nevertheless, "toe" [tu] is a
# postposition, cf. English "to" and German "zu". We prefer prepositions and
# postpositions to govern their noun phrases instead of depending on them. In
# a similar fashion, we shall make "naar" depend on "toe", while the original
# annotation does the opposite. We avoid having "AuxP" nodes as leaves.
#
# Example: ", waar men de patienten naar toe schuift"
# English: "where one pushes the patients to"
#------------------------------------------------------------------------------
sub fix_naar_toe
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Other similar examples:
        # voor/Db in_de_plaats/AuxP/X@ = in its place
        # over/Db heen/RR = lit. about away = over it
        # om/Prep/cnj en/Conj/mod langs/Prep/cnj hen/Pron/obj1 heen/Prep/hdf = to and past them (lit. about and along them away) ###!!! The coordination makes this example more complex than the others!
        # daarvoor/Adv/Db in_de_plaats/AuxP/X@ = in its place
        # om/Adv/J, zich/AuxT/P6 heen/AuxP/RR = around = lit. about themselves away
        # om/Adv/J, Venetie heen/AuxP/RR = to Venice
        # -op/Adv/AO het gevaar af/AuxP/Db = at the risk
        if($node->deprel() eq 'AuxP' && scalar($node->children())==0)
        {
            my $naar = $node->parent();
            # Block the example with coordination, allow all the others.
            if($naar->deprel() eq 'Adv')
            {
                $node->set_parent($naar->parent());
                $naar->set_parent($node);
                # Naar will keep its current deprel. Is_member should be shifted but we do not expect it to be set here.
                $node->set_is_member($naar->is_member());
                $naar->set_is_member(0);
            }
        }
    }
}



#------------------------------------------------------------------------------
# The subordinating conjunction "als" ("as") should have the label AuxC or
# AuxP but it often does not.
#------------------------------------------------------------------------------
sub fix_als
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if(lc($node->form()) eq 'als' && $node->is_subordinator())
        {
            my $parent = $node->parent();
            my @children = $node->children();
            if(defined($parent) && scalar(@children)==1 &&
               $node->deprel() !~ m/^(Aux[PC]|Coord)$/ && $children[0]->deprel() eq 'Obj')
            {
                $children[0]->set_deprel($node->deprel());
                $node->set_deprel($children[0]->is_verb() ? 'AuxC' : 'AuxP');
            }
        }
    }
}



#------------------------------------------------------------------------------
# In the original annotation, every punctuation node is attached to the
# previous non-punctuation node. This function lifts commas as high as possible
# projectively.
#------------------------------------------------------------------------------
sub lift_commas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = $#nodes-1; $i>=0; $i--)
    {
        ###!!! We currently extend the transformation to all punctuation, not just commas.
        ###!!! In future however, we want to capture pairwise punctuation (brackets, quotes) differently.
        if($nodes[$i]->form() =~ m/^\pP+$/)
        #if($nodes[$i]->form() eq ',')
        {
            # All commas were originally attached to the left.
            # If it is attached to the right, someone has already been tweaking it: do not touch it.
            if($nodes[$i]->parent()->ord()<$nodes[$i]->ord())
            {
                # Look at the right neighbor of the comma. Is it dominated by the comma's parent?
                while(!$nodes[$i]->parent()->is_root() && !$nodes[$i+1]->is_descendant_of($nodes[$i]->parent()) && $nodes[$i]->parent()!=$nodes[$i+1])
                {
                    $nodes[$i]->set_parent($nodes[$i]->parent()->parent());
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::NL::Harmonize

Converts Dutch trees from CoNLL 2006 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
# + 2012 Jindřich Libovický <jlibovicky@gmail.com> and Ondrej Košarko
# + 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
