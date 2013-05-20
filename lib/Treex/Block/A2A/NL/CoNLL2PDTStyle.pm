package Treex::Block::A2A::NL::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use Treex::Core::Cloud;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';

#------------------------------------------------------------------------------
# Reads the Dutch tree, converts morphosyntactic tags to Interset, converts
# deprel tags to afuns, transforms tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $root = $self->SUPER::process_zone( $zone, 'conll' );
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root);
    # Shifting afuns at prepositions and subordinating conjunctions must be done after coordinations are solved
    # and with special care at places where prepositions and coordinations interact.
    $self->process_prep_sub_arg_cloud($root);
    $self->fix_questionAdverbs($root);
    #$self->fix_InfinitivesNotBeingObjects($root);
    #$self->fix_SubordinatingConj($root);
    $self->check_afuns($root);
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# acroread /net/data/conll/2006/nl/doc/syn_prot.pdf &
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self       = shift;
    my $root       = shift;
    my @nodes      = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # The corpus contains the following 26 dependency relation tags:
        # ROOT app body cnj crd det dp hd hdf ld me mod obcomp obj1 obj2
        # pc pobj1 predc predm punct sat se su sup svp vc
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos    = $node->get_iset('pos');
        my $ppos   = $parent->get_iset('pos');
        my $afun;

        # Dependency of the main verb on the artificial root node.
        if ( $deprel eq 'ROOT' )
        {
            ###!!! If the root is conjunction we ought to check whether it conjoins verbs or something else!
            if ( $pos eq 'verb' || $pos eq 'conj' )
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }

        # Apposition.
        elsif ( $deprel eq 'app' )
        {
            $afun = 'Apposition';
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
                $afun = 'SubArg';
            }
            else
            {
                $self->log_sentence($node);
                log_warn('I do not know what to do with the label "body" when its parent is the root.');
                $afun = 'NR';
            }
        }

        # Conjunct.
        elsif ( $deprel eq 'cnj' )
        {
            $afun = 'CoordArg';
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
            $afun = 'AuxY';
        }

        # Determiner (article, number etc.)
        elsif ( $deprel eq 'det' )
        {
            $afun = 'Atr';
        }

        # Sort of parenthesis? There is only one occurrence of this label in the whole treebank: train/025#330.
        elsif ( $deprel eq 'dp' )
        {
            ###!!! How do we currently tag parenthesized insertions in PDT?
            $afun = 'Adv';
        }

        # Unknown meaning, very infrequent (9 occurrences). Example train/001#232: one instance of verb 'moet' ('must') attached to another.
        # Documentation page 8 Section 2.1.1: HD = werkwoordelijk hoofd finiet of niet-finiet (verbal head finite or non-finite).
        elsif ( $deprel eq 'hd' )
        {
            ###!!! Are the other occurrences similar? Look at the other examples!
            ###!!! Is there a better label?
            $afun = 'AuxV';
        }

        # Non-head part of compound preposition? Example test/001#19: 'tot nu toe' = 'up to now' (lit. 'to now up')
        ###!!! Look at the other examples, too!
        elsif ( $deprel eq 'hdf' )
        {
            $afun = 'AuxP';
        }

        # locative or directional complement
        # locatief of directioneel complement
        # Example (test/001#6): 'om de tafel zitten' = 'to sit around the table'
        elsif ( $deprel eq 'ld' )
        {
            $afun = 'Adv';
        }

        # maat (duur, gewicht...) complement
        # measure (length, weight...) complement
        # Example (test/001#85): 'vier dagen' = 'four days'
        elsif ( $deprel eq 'me' )
        {
            $afun = 'Adv';
        }

        # bijwoordelijke bepaling
        # adverbial
        elsif ( $deprel eq 'mod' )
        {
            $afun = 'Adv';
        }

        # obcomp
        # Example (test/001#17): 'zo mogelijk veel' = lit. 'so possible much' = 'as much as possible'
        # veel ( zo/mod ( mogelijk/obcomp ) )
        elsif ( $deprel eq 'obcomp' )
        {
            $afun = 'Adv';
        }

        # lijdend voorwerp
        # direct object
        elsif ( $deprel eq 'obj1' )
        {
            if ( $ppos eq 'prep' )
            {
                $afun = 'PrepArg';
            }
            else
            {
                $afun = 'Obj';
            }
        }

        # secundair object (meewerkend, belanghebbend, ondervindend)
        # secondary object (cooperative, interested, empirical)
        elsif ( $deprel eq 'obj2' )
        {
            $afun = 'Obj';
        }

        # voorzetselvoorwerp
        # prepositional object
        # This is the relation of the prepositional phrase to its parent.
        # The relation of the inner noun phrase to the preposition is obj1.
        elsif ( $deprel eq 'pc' )
        {
            $afun = 'Obj';
        }

        # voorlopig direct object
        # provisional direct object (???)
        elsif ( $deprel eq 'pobj1' )
        {
            $afun = 'Obj';
        }

        # predicatief complement
        # predicative complement
        elsif ( $deprel eq 'predc' )
        {
            $afun = 'Pnom';
        }

        # bepaling van gesteldheid 'tijdens de handeling'
        # provision of state 'during the act'
        # Example (train/001#18): 'alleen samen met het veld' = 'only together with the field'
        # The phrase depends as predm on a modal verb. Non-projectively because it lies between modifiers of the infinitive.
        elsif ( $deprel eq 'predm' )
        {
            ###!!! Is it always adverbial? Investigate the other examples!
            $afun = 'Adv';
        }

        # punctuation
        elsif ( $deprel eq 'punct' )
        {
            if ( $node->form() eq ',' )
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }

        # Only one occurrence in the whole treebank (train/017#279)
        elsif ( $deprel eq 'sat' )
        {
            $afun = 'Adv';
        }

        # verplicht reflexief object
        # obligatory reflexive object
        # Example (test/001#122): 'ontwikkelt zich' = lit. 'develops itself' = 'develops'
        elsif ( $deprel eq 'se' )
        {
            $afun = 'AuxT';
        }

        # onderwerp
        # subject
        elsif ( $deprel eq 'su' )
        {
            $afun = 'Sb';
        }

        # voorlopig subject
        # provisional subject (???)
        # Example (test/001#25): 'het ligt in de...' = 'it lies in the...'
        elsif ( $deprel eq 'sup' )
        {
            $afun = 'Sb';
        }

        # scheidbaar deel van werkwoord
        # separable part of verb (not just separable prefixes as in german: also parts of light verb constructions?)
        # Example (test/001#4): 'zorg' in 'zorg dragen' = 'ensure'
        elsif ( $deprel eq 'svp' )
        {
            $afun = 'AuxT';
        }

        # verbaal complement, werkwoordelijk deel van gezegde
        # verbal complement, verbal part of the said
        # Example (test/001#2): participle 'gekozen' in 'is gekozen' = 'is selected'
        elsif ( $deprel eq 'vc' )
        {
            $afun = 'AuxV';
        }

        else
        {
            $afun = 'NR';
        }

        $node->set_afun($afun);
        if ( $node->wild()->{conjunct} && $node->wild()->{coordinator} )
        {
            log_warn('We do not expect a node to be conjunct and coordination at the same time.');
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Dutch treebank.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_alpino($node);
    $coordination->capture_commas();
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}



#------------------------------------------------------------------------------
# Reattaches interrogative pronouns and adverbs attached directly under the
# root. ###!!! We have the same problem with relative pronouns in relative clauses
# and we should reattach those as well (i.e. to the predicate of the clause).
# It is not easy to tell what is the relation of the interrogative word towards
# the predicate: Sb, Obj, or Adv?
#------------------------------------------------------------------------------
sub fix_questionAdverbs
{
    my ( $self, $root ) = @_;
    # Find interrogative words (pronouns, adverbs) attached directly to the root.
    my @int = ();
    foreach my $node ($root->get_children())
    {
        if($node->get_iset('prontype') eq 'int')
        {
            push(@int, $node);
        }
    }
    # Reattach them if they have just one child, which is a verb.
    foreach my $int (@int)
    {
        if(scalar($int->get_children())==1 && ($int->get_children())[0]->get_iset('pos') eq 'verb')
        {
            my $verb = ($int->get_children())[0];
            # The structure is directly under the root, thus the verb now becomes the main predicate.
            $verb->set_parent($root);
            $verb->set_afun('Pred');
            # What is the relation of the interrogative to the verb?
            # If it is an adverb then the relation is probably adverbial.
            # Otherwise it can be the subject or an object. It is difficult to tell and we currently don't attempt it. ###!!!
            # Possible heuristics: It is subject unless there is another node labeled as subject.
            # (Problem: Group of nodes representing a compound verb form ('Wie heeft de Beatles opgericht?'): Where shall we look for the subject?)
            # It is subject if there is a Pnom sibling.
            # It is object if we do not have a reason to think that it is subject.
            my $afun = 'NR';
            if($int->get_iset('pos') eq 'adv')
            {
                $afun = 'Adv';
            }
            $int->set_parent($verb);
            $int->set_afun($afun);
        }
    }
}



sub fix_InfinitivesNotBeingObjects {
    my ( $self, $root ) = @_;

    my @standalonePreds = ();
    my @standaloneInfinitives = ();


    foreach my $anode ($root->get_children()) {
        if ($anode->afun eq "Pred") {
            push @standalonePreds, $anode;
        }
        elsif ($anode->tag =~ /^Vf/) {
            push @standaloneInfinitives, $anode;
        }
    }

    # fix the simpliest case...
    if (scalar @standalonePreds == 1 && scalar @standaloneInfinitives == 1) {
        my $pred = $standalonePreds[0];
        my $infinitive = $standaloneInfinitives[0];

        $infinitive->set_parent($pred);
        $infinitive->set_afun("Obj");
    }
}

sub fix_SubordinatingConj {
    my ( $self, $root ) = @_;

    # take sentences with two predicates on the root
    my @predicates = ();
    foreach my $anode ($root->get_children()) {
        if ($anode->afun eq "Pred") { push @predicates, $anode; }
    }

    # just two clauses, it should be obvious how they should look like
    if (scalar @predicates == 2) {
        my @subordConj = ("omdat", "doordat", "aangezien", "daar", "dan",
            "zodat", "opdat", "als", "zoals", "tenzij", "voordat", "nadat",
            "terwijl", "dat", "hoezeer", "indien");
        my $mainClause;
        my $depedentClause;
        my $conj;

        my @firstNodes = $predicates[0]->get_descendants({ordered=>1});
        my @secondNodes = $predicates[1]->get_descendants({ordered=>1});

        if ( @firstNodes && $firstNodes[0]->lemma =~ (join '|', @subordConj) ) {
            $depedentClause = $predicates[0];
            $mainClause = $predicates[1];
            $conj = $firstNodes[0];
        }
        elsif ( @secondNodes && $secondNodes[0]->lemma =~ (join '|', @subordConj) ) {
            $depedentClause = $predicates[1];
            $mainClause = $predicates[0];
            $conj = $secondNodes[1];
        }
        else { return; }


        $conj->set_parent($mainClause);
        $depedentClause->set_parent($conj);
        $depedentClause->set_afun("NR");
    }
}



1;

=over

=item Treex::Block::A2A::NL::CoNLL2PDTStyle

Converts Dutch trees from CoNLL 2006 to the style of
the Prague Dependency Treebank.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
# + 2012 Jindrich Libovicky <jlibovicky@gmail.com> and Ondrej Kosarko
# + 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
