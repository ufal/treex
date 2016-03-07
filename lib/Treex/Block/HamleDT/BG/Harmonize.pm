package Treex::Block::HamleDT::BG::Harmonize;
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
    default       => 'bg::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the Bulgarian tree, converts morphosyntactic tags to Interset, converts
# dependency relation labels, transforms tree to adhere to Prague guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Adjust the tree structure.
    # Phrase-based implementation of tree transformations (5.3.2016).
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToPrague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->attach_final_punctuation_to_root($root);
    $self->process_auxiliary_particles($root);
    $self->process_auxiliary_verbs($root);
    $self->mark_deficient_clausal_coordination($root);
    $self->check_deprels($root);
}



#------------------------------------------------------------------------------
# Convert dependency relation labels from BulTreeBank to the Prague style.
# http://www.bultreebank.org/dpbtb/
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
        if ( $deprel eq 'ROOT' )
        {
            if ( $node->get_iset('pos') eq 'verb' || $self->is_auxiliary_particle($node) )
            {
                $node->set_deprel('Pred');
            }
            else
            {
                $node->set_deprel('ExD');
            }
        }
        elsif ( $deprel =~ m/^x?subj$/ )
        {
            $node->set_deprel('Sb');
        }

        # comp ... Complement (arguments of: non-verbal heads, non-finite verbal heads, copula)
        # nominal predicate: check that the governing node is a copula
        elsif ( $deprel eq 'comp' )
        {

            # If parent is form of the copula verb 'to be', this complement shall be 'Pnom'.
            # Otherwise, it shall be 'Obj'.
            my $parent = $node->parent();
            my $verb   = $parent;

            # If we have not processed the auxiliary particles yet, the parent is the particle and not the copula.
            if ( $self->is_auxiliary_particle($parent) )
            {
                my $lvc = $self->get_leftmost_verbal_child($parent);
                if ( defined($lvc) )
                {
                    $verb = $lvc;
                }
            }

            # \x{435} = 'e' (cs:je)
            # \x{441}\x{430} = 'sa' (cs:jsou)
            # \x{441}\x{44A}\x{43C} = 'săm' (cs:jsem)
            # \x{431}\x{44A}\x{434}\x{435} = 'băde' (cs:bude)
            if ( $node != $verb && $verb->form() =~ m/^(\x{435}|\x{441}\x{430}|\x{431}\x{44A}\x{434}\x{435}|\x{441}\x{44A}\x{43C})$/ )
            {
                $node->set_deprel('Pnom');
            }
            else
            {
                $node->set_deprel('Obj');
            }
        }

        # obj ... Object (direct argument of a non-auxiliary verbal head)
        # indobj ... Indirect Object (indirect argument of a non-auxiliary verbal head)
        # object, indirect object or complement
        elsif ( $deprel =~ m/^((ind)?obj)$/ )
        {
            $node->set_deprel('Obj');
        }

        # adjunct: free modifier of a verb
        # xadjunct: clausal modifier
        elsif ( $deprel eq 'xadjunct' && $node->match_iset( 'pos' => 'conj', 'conjtype' => 'sub' ) )
        {
            $node->set_deprel('AuxC');
        }

        # marked ... Marked (clauses, introduced by a subordinator)
        elsif ( $deprel eq 'marked' )
        {
            $node->set_deprel('Adv');
        }
        elsif ( $deprel =~ m/^x?adjunct$/ )
        {
            $node->set_deprel('Adv');
        }

        # Pragmatic adjunct is an adjunct that does not change semantic of the head. It changes pragmatic meaning. Example: vocative phrases.
        elsif ( $deprel eq 'pragadjunct' )
        {

            # PDT: AuxY: "příslovce a částice, které nelze zařadit jinam"
            # PDT: AuxZ: "zdůrazňovací slovo"
            # The only example I saw was the word 'păk', tagged as a particle of emphasis.
            $node->set_deprel('AuxZ');
        }

        # xcomp: clausal complement
        # If the clause has got a complementizer ('that'), the complementizer is tagged 'xcomp'.
        # If there is no complementizer (such as direct speech), the root of the clause (i.e. the verb) is tagged 'xcomp'.
        elsif ( $deprel eq 'xcomp' )
        {
            if ( $node->get_iset('pos') eq 'verb' )
            {
                $node->set_deprel('Obj');
            }
            else
            {
                $node->set_deprel('AuxC');
            }
        }

        # negative particle 'ne', modifying a verb, is an adverbiale
        elsif ( $deprel eq 'mod' && lc( $node->form() ) eq "\x{43D}\x{435}" )
        {
            $node->set_deprel('Adv');
        }

        # mod: modifier (usually of a noun phrase)
        # xmod: clausal modifier
        elsif ( $deprel =~ m/^x?mod$/ )
        {
            $node->set_deprel('Atr');
        }

        # clitic: often a possessive pronoun ('si', 'ni', 'j') attached to noun, adjective or pronoun => Atr
        # sometimes a reflexive personal pronoun ('se') attached to verb (but the verb is in a nominalized form and functions as subject!)
        elsif ( $deprel eq 'clitic' )
        {
            if ( $node->match_iset( 'prontype' => 'prs', 'poss' => 'poss' ) )
            {
                $node->set_deprel('Atr');
            }
            else
            {
                $node->set_deprel('AuxT');
            }
        }

        # The conjunction 'i' can serve emphasis ('even').
        # If it builds coordination instead, its deprel will be corrected later.
        elsif ( $deprel eq 'conj' && $node->form() eq 'и' )
        {
            $node->set_deprel('AuxZ');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel eq 'punct' )
        {

            # PDT: AuxX: "čárka (ne však nositel koordinace)"
            # PDT: AuxG: "jiné grafické symboly, které neukončují větu"
            if ( $node->form() eq ',' )
            {
                $node->set_deprel('AuxX');
            }
            else
            {
                $node->set_deprel('AuxG');
            }
        }

        # Assign pseudo-deprels to coordination members so that all nodes are guaranteed to have an deprel.
        # These will hopefully be corrected later during coordination restructuring.
        elsif ( $deprel eq 'conjarg' )
        {
            $node->set_deprel('CoordArg');
            $node->wild()->{conjunct} = 1;
            # Fix error in data: conjunction labeled as conjunct.
            if($node->match_iset('pos' => 'conj', 'conjtype' => 'coor'))
            {
                my $rn = $node->get_right_neighbor();
                if($rn && $rn->conll_deprel() eq 'conjarg')
                {
                    $node->set_deprel('AuxY');
                    $node->wild()->{coordinator} = 1;
                    $node->wild()->{conjunct} = 0;
                }
            }
        }
        elsif ( $deprel eq 'conj' )
        {
            $node->set_deprel('AuxY');
            $node->wild()->{coordinator} = 1;
        }
        elsif ( $deprel =~ m/^x?prepcomp$/ )
        {
            $node->set_deprel('PrepArg');
        }
    }

    # Make sure that all nodes now have their deprels.
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if ( !$deprel )
        {
            log_warn( "Missing deprel for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }

    # Once all nodes have hopefully their deprels, prepositions must delegate their deprels to their children.
    # (Don't do this earlier. If appositions are postpositions, we would be copying deprels that don't exist yet.)
    $self->process_prep_sub_arg_cloud($root);
}



#------------------------------------------------------------------------------
# Detects auxiliary particles using Interset features.
#------------------------------------------------------------------------------
sub is_auxiliary_particle
{
    my $self = shift;
    my $node = shift;
    return $node->match_iset( 'pos' => 'part', 'verbtype' => 'aux' );
}



#------------------------------------------------------------------------------
# Finds the leftmost verbal child if any. Useful to find the verbs belonging to
# auxiliary particles. (There may be other children having the 'comp' deprel;
# these children are complements to the particle-verb pair.)
#------------------------------------------------------------------------------
sub get_leftmost_verbal_child
{
    my ($self, $node) = @_;
    return first {$_->match_iset(pos=>'verb', verbtype=>'!aux') && $_->conll_deprel eq 'comp'} $node->get_children({ordered=>1});
}



#------------------------------------------------------------------------------
# There are two auxiliary particles in BulTreeBank:
# 'да' is an infinitival* marker;
# 'ще' is used to construct the future tense.
# Both originally govern an infinitive verb clause.
# Both will be treated as subordinating conjunctions in Czech.
# *) Modern Bulgarian has no infinitive, да+[conjugated verb in present tense] is used instead.
#   There are also constructions, in which the following verb form is in past tense, then it can be considered
#   as an optative, since it expresses some wishes. For example, 'Да бях по-млад' -> 'If I was younger... [but I am not]'.
#   Also, in some cases да can also be a subordinator: Чакам да дойдеш -> 'I wait [wanting] you to come / čekám abys přišel.
#   Then we might say it is subjunctive.
# Passive constructions such as "тя(parent=да) трябва да(parent=трябва) е(parent=да) изписана(parent=да)"
# should be transformed to "тя(parent=изписана) трябва да(parent=трябва,deprel=AuxC) е(parent=изписана,deprel=AuxV) изписана(parent=да)"
# See https://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s03.html#prstapas_rozliseni_stavu_a_pasiva_
#------------------------------------------------------------------------------
sub process_auxiliary_particles
{
    my ($self, $root) = @_;
    foreach my $node ($root->get_descendants()) {
        next if !$self->is_auxiliary_particle($node);

        # Consider the first verbal child of the particle the clausal head.
        my $head = $self->get_leftmost_verbal_child($node);
        next if !$head;

        my @children = $node->children();

        # Reattach all other children to the new head.
        # Mark auxiliary "е" in passive constructions as AuxV
        foreach my $child (@children) {
            if ( $child != $head ) {
                $child->set_parent($head);
                if ($child->iset->verbtype eq 'aux'){
                    $child->set_deprel('AuxV');
                }
            }
        }

        # Experiment: different treatment of 'da' and 'šte'.
        if ( $node->form() eq 'да' ) {

            # Treat the particle as a subordinating conjunction.
            $node->set_deprel('AuxC');
            # "да" needs to be marked as an infinitive in order to collapse modal+да constructions
            # (да is a kind of infinitive particle, but the verb it precedes is fully conjugated).
            # We cannot do this inside Interset driver because tag "Tx" can be also "ще",
            # which should not be marked as an infinitive.
            $node->iset->set_verbform('inf');
        } else {   # ще
            ###!!! We used to call the inherited method lift node( $head, 'AuxV' ) here.
            ###!!! The method is now deprecated because it did not handle coordination properly.
            ###!!! The node raising should be done within the phrase model.
        }
    }
    return;
}



#------------------------------------------------------------------------------
# Modal verbs are not marked in BulTreeBank, so we need to detect them based on lemmas.
#------------------------------------------------------------------------------
sub is_modal
{
    my ($self, $node) = @_;
    # TODO: add the rest of BG modals
    return 1 if $node->lemma =~ /^(трябва|мога)(\_.*)?$/;
	return 0;
}



#------------------------------------------------------------------------------
# Constructions like "mogăl bi" (cs:mohl by). "mogăl" is a participle (in this
# case modal but it does not matter). "bi" is a form of the auxiliary verb
# "to be". In BulTreeBank, "bi" governs "mogăl". In PDT it would be vice versa.
#------------------------------------------------------------------------------
sub process_auxiliary_verbs
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    my @liftnodes;

    # Search for nodes to lift.
    foreach my $node (@nodes)
    {
        if ($self->is_modal($node))
        {
            $node->iset->set_verbtype('mod');
        }
        # Is this a non-auxiliary verb?
        # Is its parent an auxiliary verb?
        if (
            $node->match_iset( 'pos' => 'verb', 'verbtype' => '!aux', 'verbform' => 'part' )

            # &&
            # $node->form() eq 'могъл'
            )
        {
            my $parent = $node->parent();
            if (!$parent->is_root()
                &&

                # $parent->get_attr('conll_pos') eq 'Vxi'
                # $parent->match_iset('pos' => 'verb', 'verbtype' => 'aux', 'person' => 3, 'number' => 'sing')
                $parent->form() =~ m/^(би(ха)?|бях)$/
                )
            {
                push( @liftnodes, $node );
            }
        }
    }
    # Lift the identified nodes.
    foreach my $node (@liftnodes)
    {
        ###!!! We used to call the inherited method lift node( $node, 'AuxV' ) here.
        ###!!! The method is now deprecated because it did not handle coordination properly.
        ###!!! The node raising should be done within the phrase model.
    }
}



#------------------------------------------------------------------------------
# Conjunction as the first word of the sentence is attached as 'conj' to the main verb in BulTreeBank.
# In PDT, it is the root of the sentence, marked as coordination, whose only member is the main verb.
#------------------------------------------------------------------------------
sub mark_deficient_clausal_coordination
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    if ( $nodes[0]->conll_deprel() eq 'conj' )
    {
        my $parent = $nodes[0]->parent();
        if ( $parent->conll_deprel() eq 'ROOT' )
        {
            my $grandparent = $parent->parent();
            $nodes[0]->set_deprel('Coord');
            $nodes[0]->set_parent($grandparent);
            $parent->set_parent( $nodes[0] );
            $parent->set_is_member(1);
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::BG::Harmonize

Converts trees coming from BulTreeBank via the CoNLL-X format to the style of
the HamleDT (Prague). Converts tags and restructures the tree.

=back

=cut

# Copyright 2011, 2014, 2016 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
