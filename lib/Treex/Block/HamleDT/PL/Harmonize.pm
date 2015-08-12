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
#  neg obj obj_th pd pre_coord pred punct refl subj; not including errors
# (twice 'interp' instead of 'punct' and once 'ne_' instead of 'ne')
# ### TODO ### - add comments to the individual conditions
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
        # adjunct - 'a non-subcategorised dependent with the modifying function'
        if ($deprel eq 'adjunct')
        {
            # parent is a verb, an adjective or an adverb -> Adv
            # particle, e.g. "dopiero" = "only"
            ###!!! TODO: Restructure this!
            ###!!! "dopiero po przyjeździe" = "only after arrival" is analyzed as adjunct(dopiero, po); comp(po, przyjeździe)
            ###!!! but we want to get AuxP(po, przyjeździe); AuxZ(przyjeździe, dopiero).
            if ($parent->iset()->pos() =~ m/^(verb|adj|adv|part)$/)
            {
                $node->set_afun('Adv');
            }
            # parent is a noun -> Atr
            elsif ($parent->is_noun() || $parent->is_numeral())
            {
                $node->set_afun('Atr');
            }
            ###!!! Node and parent are prepositions. Example: "diety od 1500 do 2000 złotych"; adjunct(diety, od); comp(od, 1500); adjunct(od, do); comp(do, 2000).
            ###!!! We may want to restructure structures like this one.
            elsif ($parent->is_adposition())
            {
                $node->set_afun('Atr');
            }
            # If the parent is a coordinating conjunction, the adjunct modifies the entire coordination.
            # We have to examine the part of speech of the conjuncts.
            elsif ($parent->is_coordinator() || $parent->is_punctuation())
            {
                my @conjuncts = grep {$_->conll_deprel() eq 'conjunct'} $parent->children();
                if (any {$_->is_noun()} @conjuncts)
                {
                    $node->set_afun('Atr');
                }
                else
                {
                    $node->set_afun('Adv');
                }
            }
            # otherwise -> NR
            else
            {
                $node->set_afun('NR');
            }
        }
        # complement
        elsif ($deprel eq 'comp')
        {
            # parent is a preposition -> PrepArg - solved by a separate subroutine
            if ($parent->is_adposition())
            {
                $node->set_afun('PrepArg');
            }
            # parent is a numeral -> Atr (counted noun in genitive is governed by the numeral, like in Czech)
            elsif ($parent->is_numeral())
            {
                $node->set_afun('Atr');
            }
            # parent is a noun -> Atr
            elsif ($parent->is_noun())
            {
                $node->set_afun('Atr');
            }
            # parent is a verb
            # or adjective (especially deverbative: "zakończony")
            elsif ($parent->is_verb() || $parent->is_adjective())
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
                elsif ($posnode->get_iset('pos') eq 'adj')
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
                # otherwise -> NR
                else
                {
                    $node->set_afun('NR');
                }
            }
            # otherwise -> NR
            else
            {
                $node->set_afun('NR');
            }
        }
        # comp_inf ... infinitival complement
        # comp_fin ... clausal complement
        elsif ($deprel =~ m/^comp_(inf|fin)$/)
        {
            if ($parent->is_adposition())
            {
                $node->set_afun('PrepArg');
            }
            elsif ($parent->is_noun())
            {
                $node->set_afun('Atr');
            }
            elsif ($parent->is_verb() || $parent->is_adjective())
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
        # pred ... predicate
        elsif ($deprel eq 'pred')
        {
            $node->set_afun('Pred');
        }
        # subj ... subject
        elsif ($deprel eq 'subj')
        {
            $node->set_afun('Sb');
        }
        # conjunct
        elsif ($deprel eq 'conjunct')
        {
            # node is a coordination argument - solved in a separate subroutine
            $node->set_afun('CoordArg');
            # node is a conjunct
            $node->wild()->{'conjunct'} = 1;
            # parent must be a coordinator (does it?)
            $parent->wild()->{'coordinator'} = 1;
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
        elsif ($deprel eq 'ne')
        {
            $node->set_afun('Atr');
            # ### TODO ### interpunkce by mela dostat AuxG; struktura! - hlava by mela byt nejpravejsi uzel
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
        # mwe ... multi-word expression
        elsif ($deprel eq 'mwe')
        {
            $node->set_afun('AuxY');
        }
        # coord_punct ... punctuation conjunction
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
        }
        # app .. apposition
        # dependent on the first part of the apposition
        elsif ($deprel eq 'app')
        {
            $node->set_afun('Apposition');
        }
        # coord ... coordinating conjunction
        # coordinates two sentences (in other cases, the conjunction bears the relation to its parent)
        elsif ($deprel eq 'coord')
        {
            $node->wild()->{'coordinator'} = 1;
            $node->set_afun('Pred');
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
        # pre_coord ... pre-conjunction; first part of a correlative conjunction
        elsif ($deprel eq 'pre_coord')
        {
            $node->set_afun('AuxY');
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
}



#------------------------------------------------------------------------------
# Detects coordination structure according to current annotation (dependency
# links between nodes and labels of the relations). Expects the Polish style
# of the Prague family(?) - the head of the coordination bears the label of the
# relation between the coordination and its parent. The afuns of conjuncts just
# mark them as conjuncts; the shared modifiers are distinguished by having
# a different afun. The method assumes that nothing has been normalized yet.
# Expects the coordinators and conjuncts to have the respective attribute in
# wild()
# ### TODO ### - check/correct; might be better to move into the PL::Harmonize?
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in the Polish
# treebank.
#------------------------------------------------------------------------------
# sub detect_coordination {
#     my $self = shift;
#     my $node = shift;
#     my $coordination = shift;
#     my $debug = shift;
#     $self->detect_polish($coordination, $node);
#     # The caller does not know where to apply recursion because it depends on annotation style.
#     # Return all conjuncts and shared modifiers for the Prague family of styles.
#     # Return orphan conjuncts and all shared and private modifiers for the other styles.
#     my @recurse = $coordination->get_conjuncts();
#     push(@recurse, $coordination->get_shared_modifiers());
#     return @recurse;
# }

sub detect_coordination {
    my $self = shift;
    my $node = shift;  # suspected root node of coordination
    my $coordination = shift;
    my $debug = shift;
    log_fatal("Missing node") unless (defined($node));
    my @children = $node->children();
    my @conjuncts = grep {$_->wild()->{'conjunct'}} (@children);
    return unless (@conjuncts);
    $coordination->set_parent($node->parent());
    $coordination->add_delimiter($node, $node->get_iset('pos') eq 'punc');
    $coordination->set_afun($node->afun());
    for my $child (@children) {
        if ($child->wild()->{'conjunct'}) {
            my $orphan = 0;
            $coordination->add_conjunct($child, $orphan);
        }
        elsif ($child->wild()->{'coordinator'}) {
            my $symbol = 1;
            $coordination->add_delimiter($child, $symbol);
        }
        else {
            $coordination->add_shared_modifier($child);
        }
    }
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}


### NOT FINISHED - WORK IN PROGRESS ###

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
