package Treex::Block::HamleDT::PL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'pl::ipipan',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

my $debug = 0;



#------------------------------------------------------------------------------
# Reads the Polish tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
# ### TODO ###
# - improve deprel_to_afun(),
#   - handling of complements of all types (incl. subordination)
#   - NumArgs
#   - PrepArgs (seem to be working quite well)
#   - eliminate 'NR's
#   - tabularize
# - improve coordination restructuring
#   (in particular for the sentence-level coordination with no 'pred' deprel)
# - test -> solve remaining problems
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;

    my $root = $self->SUPER::process_zone($zone);
#    $self->process_args($root);
    $self->attach_final_punctuation_to_root($root);
    $self->restructure_coordination($root, $debug);
    $self->process_prep_sub_arg_cloud($root);
    $self->check_afuns($root);
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
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    # Compose a tag string in the form expected by the pl::ipipan Interset driver.
    $conll_feat =~ s/\|/:/g;
    return "$conll_pos:$conll_feat";
}



#------------------------------------------------------------------------------
# Try to convert dependency relation tags to analytical functions.
# http://zil.ipipan.waw.pl/FunkcjeZaleznosciowe
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# There are 25 distinct dependency relation tags: abbrev_punct adjunct aglt app
# aux comp comp_fin comp_inf complm cond conjunct coord coord_punct imp mwe ne
# neg obj obj_th pd pre_coord pred punct refl subj.
# In addition this method also handles tags that occur in the treebank by
# error: twice 'interp' instead of 'punct' and once 'ne_' instead of 'ne'.
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self   = shift;
    my $root   = shift;
    my @nodes  = $root->get_descendants();
    for my $node (@nodes)
    {
        my $deprel = $node->conll_deprel;
        my $parent = $node->get_parent();
        # If the parent is a coordinating conjunction, the node modifies the entire coordination
        # and we have to examine the effective parents: the conjuncts.
        my $eparent = $parent;
        if ($parent->is_coordinator() || $parent->is_punctuation())
        {
            my @conjuncts = grep {$_->conll_deprel() eq 'conjunct'} $parent->children();
            if (@conjuncts)
            {
                ###!!! At the moment we ignore the possibility of a nested coordination, i.e. $conjunct[0] is again a conjunction.
                ###!!! We also ignore that the conjuncts may not all be the same part of speech.
                $eparent = $conjuncts[0];
            }
        }
        # pred ... predicate
        if ($deprel eq 'pred')
        {
            $node->set_afun('Pred');
        }
        # subj ... subject
        elsif ($deprel eq 'subj')
        {
            $node->set_afun('Sb');
        }
        # adjunct - 'a non-subcategorised dependent with the modifying function'
        elsif ($deprel eq 'adjunct')
        {
            # parent is a verb, an adjective or an adverb -> Adv
            # particle, e.g. "dopiero" = "only"
            ###!!! TODO: Restructure this!
            ###!!! "dopiero po przyjeździe" = "only after arrival" is analyzed as adjunct(dopiero, po); comp(po, przyjeździe)
            ###!!! but we want to get AuxP(po, przyjeździe); AuxZ(przyjeździe, dopiero).
            if ($eparent->iset()->pos() =~ m/^(verb|adj|adv|part)$/)
            {
                if ($node->is_subordinator() && $node->is_leaf())
                {
                    # If it is not leaf then its child will get SubArg and later
                    # transformations will cause this node to become AuxC.
                    $node->set_afun('AuxC');
                }
                else
                {
                    $node->set_afun('Adv');
                }
            }
            # parent is a noun -> Atr
            elsif ($eparent->is_noun() || $eparent->is_numeral())
            {
                $node->set_afun('Atr');
            }
            ###!!! Node and parent are prepositions. Example: "diety od 1500 do 2000 złotych"; adjunct(diety, od); comp(od, 1500); adjunct(od, do); comp(do, 2000).
            ###!!! We may want to restructure structures like this one.
            elsif ($eparent->is_adposition())
            {
                $node->set_afun('Atr');
            }
            # unknown part of speech of the parent, e.g. abbreviation (could be both noun and verb; all examples I have seen were nouns though)
            else
            {
                $node->set_afun('Atr');
            }
        }
        # complement
        elsif ($deprel eq 'comp')
        {
            # parent is a preposition -> PrepArg - solved by a separate subroutine
            if ($eparent->is_adposition())
            {
                $node->set_afun('PrepArg');
            }
            # parent is a subordinating conjunction -> SubArg - solved by a separate subroutine
            elsif ($eparent->is_subordinator())
            {
                $node->set_afun('SubArg');
            }
            # parent is a numeral -> Atr (counted noun in genitive is governed by the numeral, like in Czech)
            elsif ($eparent->is_numeral())
            {
                $node->set_afun('Atr');
            }
            # parent is a noun -> Atr
            elsif ($eparent->is_noun())
            {
                $node->set_afun('Atr');
            }
            # parent is a verb
            # or adjective (especially deverbative: "zakończony")
            elsif ($eparent->is_verb() || $eparent->is_adjective())
            {
                # If the node is a coordinating conjunction, we must inspect the part of speech of its conjuncts.
                my $posnode = $node;
                if($node->is_coordinator() || $node->is_punctuation())
                {
                    my @conjuncts = grep {$_->conll_deprel() eq 'conjunct'} $node->children();
                    if(@conjuncts)
                    {
                        $posnode = $conjuncts[0];
                    }
                }
                # node is an adverb -> Adv
                if ($posnode->is_adverb())
                {
                    $node->set_afun('Adv');
                }
                # node is an adjective -> Atv
                elsif ($posnode->is_adjective() || $posnode->is_participle())
                {
                    $node->set_afun('Atv');
                }
                # node is a syntactic noun -> Obj
                ###!!! The reflexive pronoun "się" is (sometimes or always?) tagged "qub", i.e. particle. We may want to fix the part of speech as well.
                # Example: Jakiś czas mierzyli się wzrokiem. (For some time they measured each other.)
                elsif ($posnode->is_noun() or $posnode->conll_pos =~ m/(inf)|(ger)|(num)/ or $posnode->form() =~ m/^się$/i)
                {
                    $node->set_afun('Obj');
                }
                # node is a preposition and for the moment it should hold the function of the whole prepositional phrase (which will later be propagated to the argument of the preposition)
                # this should work the same way as noun phrases -> Obj
                elsif ($posnode->is_adposition())
                {
                    $node->set_afun('Obj');
                }
                # otherwise -> Atr
                else
                {
                    $node->set_afun('Atr');
                }
            }
            # parent is an adverb
            # Example: odpowiednio do tego (in accord with that); comp(odpowiednio, do); comp(do, tego)
            elsif ($eparent->is_adverb())
            {
                $node->set_afun('Adv');
            }
            # otherwise -> NR
            else
            {
                $node->set_afun('Atr');
            }
        }
        # comp_inf ... infinitival complement
        # comp_fin ... clausal complement
        elsif ($deprel =~ m/^comp_(inf|fin)$/)
        {
            if ($eparent->is_adposition())
            {
                $node->set_afun('PrepArg');
            }
            elsif ($eparent->is_subordinator())
            {
                $node->set_afun('SubArg');
            }
            elsif ($eparent->is_noun())
            {
                $node->set_afun('Atr');
            }
            elsif ($eparent->is_verb() || $eparent->is_adjective())
            {
                if ($node->is_adverb())
                {
                    $node->set_afun('Adv');
                }
                elsif ($node->is_adjective())
                {
                    $node->set_afun('Atv');
                }
                else
                {
                    $node->set_afun('Obj')
                }
            }
            else
            {
                # Infinitive complements are usually labeled Obj in the Prague treebanks.
                $node->set_afun('Obj');
            }
        }
        # obj ... object
        # obj_th ... dative object
        elsif ($deprel =~ m/^obj/)
        { # 'obj' and 'obj_th'
            $node->set_afun('Obj');
        }
        # refl ... reflexive marker
        # TODO: how to decide between AuxT and Obj?
        elsif ($deprel eq 'refl')
        {
            $node->set_afun('AuxT');
        }
        # neg ... negation marker
        elsif ($deprel eq 'neg')
        {
            $node->set_afun('Neg');
        }
        # pd ... predicative complement
        elsif ($deprel eq 'pd')
        {
            $node->set_afun('Pnom');
        }
        # ne ... named entity
        # ne_ ... one occurence – a typo?
        elsif ($deprel =~ m/^ne_?$/)
        {
            $node->set_afun('Atr');
            # ### TODO ### interpunkce by mela dostat AuxG; struktura! - hlava by mela byt nejpravejsi uzel
        }
        # mwe ... multi-word expression
        # It occurs in compound prepositions (adverb + simple preposition) as the second element (preposition):
        # zgodnie z projektem ... XXX(PARENT, zgodnie); mwe(zgodnie, z); comp(zgodnie, projektem)
        # In PDT, such constructions are annotated using AuxP:
        # AuxP(PARENT, zgodnie); AuxP(zgodnie, z); XXX(zgodnie, projektem)
        elsif ($deprel eq 'mwe')
        {
            $node->set_afun('AuxP');
        }
        # complm ... complementizer
        elsif ($deprel eq 'complm')
        {
            $node->set_afun('AuxP');
        }
        # aglt ... mobile inflection
        elsif ($deprel eq 'aglt')
        {
            $node->set_afun('AuxV');
        }
        # aux ... auxiliary
        elsif ($deprel eq 'aux')
        {
            $node->set_afun('AuxV');
        }
        # app .. apposition
        # dependent on the first part of the apposition
        elsif ($deprel eq 'app')
        {
            $node->set_afun('Apposition');
        }
        # coord ... coordinating conjunction
        # This label occurs only with top-level coordinations (coordinate predicates / clauses).
        # In other cases, the label of the coordination head reflects the coordination's relation to its parent.
        elsif ($deprel eq 'coord')
        {
            $node->wild()->{'coordinator'} = 1;
            $node->set_afun('Pred');
        }
        # coord_punct ... punctuation instead of coordinating conjunction
        # As with coord, this label normally (except for one error) occurs only with top-level coordinations.
        # It is used for the punctuation symbol that serves as the coordination head; additional commas with three and more conjuncts are labeled just "punct".
        elsif ($deprel eq 'coord_punct')
        {
            $node->wild()->{'coordinator'} = 1;
            if ($node->form eq ',')
            {
                $node->set_afun('AuxX');
            }
            else
            {
                $node->set_afun('AuxG');
            }
            # There is one error where this is not a top-level coordination, but it is a nested coordination, i.e. this node is a coordinator and a conjunct at the same time.
            ###!!! IT DOES NOT WORK AT THE MOMENT! Either we are calling it in a wrong context, or there is a problem with the detect_coordination() function.
            ###!!! Thus I am turning it off and temporarily leaving 5 untranslated deprels in the data.
            if (0 && !$parent->is_root() && any {$_->conll_deprel() eq 'conjunct'} ($parent->children()))
            {
                $node->set_afun('CoordArg');
                $node->wild()->{'conjunct'} = 1;
            }
        }
        # conjunct
        elsif ($deprel eq 'conjunct')
        {
            # node is a coordination argument - solved in a separate subroutine
            $node->set_afun('CoordArg');
            # node is a conjunct
            $node->wild()->{'conjunct'} = 1;
            # parent must be a coordinator (must it?)
            $parent->wild()->{'coordinator'} = 1;
        }
        # pre_coord ... pre-conjunction; first part of a correlative conjunction (such as English "either ... or")
        elsif ($deprel eq 'pre_coord')
        {
            $node->set_afun('AuxY');
        }
        # punct ... punctuation marker
        elsif ($deprel eq 'punct')
        {
            # comma gets AuxX
            if ($node->form eq ',')
            {
                $node->set_afun('AuxX');
            }
            # all other symbols get AuxG
            else
            {
                $node->set_afun('AuxG');
            }
            # AuxK is assigned later in attach_final_punctuation_to_root()
        }
        # abbrev_punct ... abbreviation marker
        elsif ($deprel eq 'abbrev_punct')
        {
            $node->set_afun('AuxG');
        }
        # cond ... conditional clitic
        elsif ($deprel eq 'cond')
        {
            $node->set_afun('AuxV');
        }
        # imp ... imperative marker
        elsif ($deprel eq 'imp')
        {
            $node->set_afun('AuxV');
        }
        else
        {
            $node->set_afun('NR');
        }
    }
    # Make sure that all nodes now have their afuns.
    for my $node (@nodes)
    {
        my $afun = $node->afun();
        if ( !$afun )
        {
            $self->log_sentence($root);
            # If the following log is warn, we will be waiting for tons of warnings until we can look at the actual data.
            # If it is fatal however, the current tree will not be saved and we only will be able to examine the original tree.
            log_fatal( "Missing afun for node " . $node->form() . "/" . $node->tag() . "/" . $node->conll_deprel() );
        }
    }
    # Fix known annotation errors.
    # We should fix it now, before the superordinate class will perform other tree operations.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from deprel_to_afun() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my $sentence = $root->get_subtree_string();
    my @nodes = $root->get_descendants({'ordered' => 1});
    if($sentence =~ m/^Zachrobotało w bramie ?, zachrzęściło i błysnęła latarka Softa ?\. ?$/i)
    {
        my $zachrobotalo = $nodes[0];
        my $comma        = $nodes[3];
        my $zachrzescilo = $nodes[4];
        my $i            = $nodes[5];
        $zachrobotalo->set_parent($i);
        $zachrobotalo->set_afun('CoordArg');
        $zachrobotalo->wild()->{'conjunct'} = 1;
        $zachrzescilo->set_parent($i);
        $zachrzescilo->set_afun('CoordArg');
        $zachrzescilo->wild()->{'conjunct'} = 1;
        $comma->set_afun('AuxX');
        delete($comma->wild()->{'coordinator'});
        $i->wild()->{'coordinator'} = 1;
    }
    elsif($sentence =~ m/^Włoszczyznę pokroić ?, kapustę poszatkować i razem udusić ?\. ?$/i)
    {
        my $pokroic     = $nodes[1];
        my $comma       = $nodes[2];
        my $poszatkowac = $nodes[4];
        my $i           = $nodes[5];
        $pokroic->set_parent($i);
        $pokroic->set_afun('CoordArg');
        $pokroic->wild()->{'conjunct'} = 1;
        $poszatkowac->set_parent($i);
        $poszatkowac->set_afun('CoordArg');
        $poszatkowac->wild()->{'conjunct'} = 1;
        $comma->set_afun('AuxX');
        delete($comma->wild()->{'coordinator'});
        $i->wild()->{'coordinator'} = 1;
    }
    elsif($sentence =~ m/, 300 tys . zł pochodzić będzie z kredytu , a/i && scalar(@nodes)>13 && $nodes[13]->form() eq 'pochodzić')
    {
        my $comma     = $nodes[8];
        my $pochodzic = $nodes[13];
        my $a         = $nodes[18];
        $pochodzic->set_parent($a);
        $pochodzic->set_afun('CoordArg');
        $pochodzic->wild()->{'conjunct'} = 1;
        delete($comma->wild()->{'coordinator'});
        $a->wild()->{'coordinator'} = 1;
    }
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects the Prague family
# in the Alpino style (head label marks relation between coordination and its
# parent; conjunct labels only say that they are conjuncts).
# The method assumes that nothing has been normalized yet.
# Expects the coordinators and conjuncts to have the respective wild attribute.
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



1;

=over

=item Treex::Block::HamleDT::PL::Harmonize

Converts trees coming from Polish Dependency Treebank via the CoNLL-X format to the style of
the HamleDT/Prague. Converts tags and restructures the tree.

=back

=cut

# Copyright 2013 Jan Mašek <honza.masek@gmail.com>

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
