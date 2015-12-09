package Treex::Block::HamleDT::SK::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'sk::snk',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Slovak tree, converts morphosyntactic tags and dependency relation
# labels, and transforms tree to adhere to the HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
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
    return $node->tag();
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
    # Make sure that the dependency relation label is in the deprel attribute and not somewhere else.
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        $node->set_deprel($deprel);
    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real deprel. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->pdt_to_treex_is_member_conversion($root);
    # Try to fix annotation inconsistencies around coordination.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            if(!$parent->deprel() =~ m/^(Coord|Apos)$/)
            {
                if($parent->is_conjunction() || $parent->form() && $parent->form() =~ m/^(ani|,|;|:|-+)$/)
                {
                    $parent->set_deprel('Coord');
                }
                else
                {
                    $node->set_is_member(undef);
                }
            }
        }
        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr) -> Atr
        if($node->deprel() =~ m/^(AtrAtr)|(AtrAdv)|(AdvAtr)|(AtrObj)|(ObjAtr)/)
        {
            $node->set_deprel('Atr');
        }
        # negation (can be either AuxY or AuxZ in the input)
        if ($node->deprel() =~ m/^Aux[YZ]$/ && $node->form() =~ m/^nie$/i)
        {
            $node->set_deprel('Neg');
        }
    }
    # Now the above conversion could be trigerred at new places.
    # (But we have to do it above as well, otherwise the correction of coordination inconsistencies would be less successful.)
    $self->pdt_to_treex_is_member_conversion($root);
    # Guess deprels that the annotators have not assigned.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'NR')
        {
            $node->set_deprel($self->guess_deprel($node));
        }
    }
}

#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
# This method will be called right after converting the deprels to the
# harmonized label set, but before any tree transformations.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # Deficient sentential coordination ("And" at the beginning of the sentence):
        # There are hundreds of cases where the conjunction is labeled Coord but the child has not is_member set.
        if($node->deprel() =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} (@children))
        {
            # If the node is leaf we cannot hope to find any conjuncts.
            # The same holds if the node is not leaf but its children are not eligible for conjuncts.
            if(scalar(grep {$_->deprel() !~ m/^Aux[GXY]$/} (@children))==0)
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
                    # It is not punctuation, thus it is a word or a number.
                    # As it was labeled Coord, let us assume that it is an extra conjunction in coordination that is headed by another conjunction.
                    $node->set_deprel('AuxY');
                }
            }
            # There are possible conjuncts and we must identify them.
            else
            {
                $self->identify_coap_members($node);
            }
        }
        # Verb "je" labeled AuxX.
        elsif($node->form() eq 'je' && $node->deprel() eq 'AuxX' && $parent->deprel() eq 'Coord')
        {
            $node->set_deprel('Pred');
            $node->set_is_member(1);
        }
        # Conjunction "akoby" labeled AuxY ("Lenže akoby sa díval na...")
        elsif($node->form() eq 'akoby' && $node->deprel() eq 'AuxY' && $parent->deprel() eq 'Coord')
        {
            $node->set_deprel('AuxC');
            $node->set_is_member(1);
        }
        # Colon at sentence end, labeled Apos although there are no children.
        elsif($node->form() eq ':' && $node->deprel() eq 'Apos' && $node->is_leaf())
        {
            $node->set_deprel('AuxG');
        }
        # Colon at sentence end, subordinate clause attached to it instead of the verb.
        elsif($node->form() eq 'a' && !$parent->is_root() && $parent->form() eq ':' && !$parent->get_next_node() && !$parent->parent()->is_root() && $parent->parent()->is_verb())
        {
            my $verb = $parent->parent();
            $node->set_parent($verb);
            $node->set_is_member(undef);
        }
    }
}

#------------------------------------------------------------------------------
# The Slovak Treebank suffers from several hundred unassigned syntactic tags.
# This function can be used to guess them based on morphosyntactic features of
# parent and child.
#------------------------------------------------------------------------------
sub guess_deprel
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent(); ###!!! eparents? Akorát že ty závisí na správných deprelech a rodič zatím taky nemusí mít správný deprel.
    my $pos = $node->iset()->pos();
    my $ppos = $parent->iset()->pos();
    my $deprel = 'NR';
    if($parent->is_root())
    {
        if($pos eq 'verb')
        {
            $deprel = 'Pred';
        }
        elsif($node->form() eq 'ale' && grep {$_->deprel() !~ m/^(Aux[GXY])$/} ($node->children()))
        {
            $deprel = 'Coord';
            foreach my $child ($node->children())
            {
                if($child->deprel() !~ m/^Aux[GXY]$/)
                {
                    $child->set_is_member(1);
                }
                else
                {
                    $child->set_is_member(undef);
                }
            }
        }
    }
    # We may not be able to recognize coordination if parent's label is yet to be guessed.
    # But if we know there is a Coord, why not use it?
    elsif($parent->deprel() eq 'Coord')
    {
        if($node->is_leaf() && $pos eq 'punc')
        {
            if($node->form() eq ',')
            {
                $deprel = 'AuxX';
            }
            else
            {
                $deprel = 'AuxG';
            }
        }
        else # probably conjunct
        {
            ###!!! We should look at the parent of the coordination and guess the function of the coordination.
            ###!!! Or figure out functions of other conjuncts if they have them.
            $deprel = 'ExD';
            $node->set_is_member(1);
        }
    }
    # Preposition is always AuxP. The real function is tagged at its argument.
    elsif($pos eq 'adp')
    {
        $deprel = 'AuxP';
    }
    elsif($parent->form() eq 'než')
    {
        # větší než já
        # V PDT se podobné fráze analyzují jako elipsa ("má větší příjem než [mám] já").
        $deprel = 'ExD';
    }
    elsif($parent->form() eq 'ako')
    {
        # cien známych ako Kristián
        # V PDT se fráze se spojkou "jako" analyzují jako doplněk. Ovšem "jako" tam visí až na doplňku, čímž se liší od jiných výskytů podřadících spojek a předložek.
        $deprel = 'Atv';
    }
    elsif($parent->form() eq 'že')
    {
        $deprel = 'Obj';
    }
    elsif($ppos eq 'noun')
    {
        $deprel = 'Atr';
    }
    elsif($node->is_foreign())
    {
        $deprel = 'Atr';
    }
    elsif($ppos eq 'adj' && ($pos eq 'adj' || $node->iset()->prontype() ne ''))
    {
        $deprel = 'Atr';
    }
    elsif($ppos eq 'num' && $pos eq 'noun') # example: viacero stredísk
    {
        $deprel = 'Atr';
    }
    elsif($ppos eq 'verb')
    {
        my $case = $node->iset()->case();
        if($node->form() eq 'nie')
        {
            ###!!! This should be Neg but we should change it in all nodes, not just in those where we guess labels.
            $deprel = 'Adv';
        }
        elsif($pos eq 'noun')
        {
            if($case eq 'nom')
            {
                $deprel = 'Sb';
            }
            else
            {
                $deprel = 'Obj';
            }
        }
        elsif($pos eq 'adj' && $case eq 'nom' && $parent->lemma() =~ m/^(ne)?byť$/)
        {
            $deprel = 'Pnom';
        }
        elsif($pos eq 'verb') # especially infinitive
        {
            $deprel = 'Obj';
        }
        elsif($pos eq 'adv')
        {
            $deprel = 'Adv';
        }
        elsif($node->form() =~ m/^ak$/i)
        {
            $deprel = 'AuxC';
        }
    }
    return $deprel;
}

1;

=over

=item Treex::Block::HamleDT::SK::Harmonize

Converts SNK (Slovak National Corpus) trees to the HamleDT style. Currently
it only involves conversion of the morphological tags (and Interset decoding).

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
