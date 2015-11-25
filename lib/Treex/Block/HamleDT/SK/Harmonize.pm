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
# Reads the Slovak tree, converts morphosyntactic tags to the PDT tagset,
# converts afuns if applicable, transforms tree to adhere to HamleDT guidelines.
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
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real afun. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
    # Try to fix annotation inconsistencies around coordination.
    foreach my $node (@nodes)
    {
        if($node->is_member())
        {
            my $parent = $node->parent();
            if(!$parent->is_coap_root())
            {
                if($parent->is_conjunction() || $parent->form() && $parent->form() =~ m/^(ani|,|;|:|-+)$/)
                {
                    $parent->set_afun('Coord');
                }
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr) -> Atr
        if ( $node->afun() =~ m/^(AtrAtr)|(AtrAdv)|(AdvAtr)|(AtrObj)|(ObjAtr)/ )
        {
            $node->set_afun('Atr');
        }
        # negation (can be either AuxY or AuxZ in the input)
        if ($node->afun() =~ m/^Aux[YZ]$/ && $node->form() =~ m/^nie$/i)
        {
            $node->set_afun('Neg');
        }
    }
    # Now the above conversion could be trigerred at new places.
    # (But we have to do it above as well, otherwise the correction of coordination inconsistencies would be less successful.)
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
    # Guess afuns that the annotators have not assigned.
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'NR')
        {
            $node->set_afun($self->guess_afun($node));
        }
    }
    # Fix known annotation errors. They include coordination, i.e. the tree may now not be valid.
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
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # Deficient sentential coordination ("And" at the beginning of the sentence):
        # There are hundreds of cases where the conjunction is labeled Coord but the child has not is_member set.
        if($node->afun() =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} (@children))
        {
            # If the node is leaf we cannot hope to find any conjuncts.
            # The same holds if the node is not leaf but its children are not eligible for conjuncts.
            if(scalar(grep {$_->afun() !~ m/^Aux[GXY]$/} (@children))==0)
            {
                if($node->form() eq ',')
                {
                    $node->set_afun('AuxX');
                }
                elsif($node->is_punctuation())
                {
                    $node->set_afun('AuxG');
                }
                else
                {
                    # It is not punctuation, thus it is a word or a number.
                    # As it was labeled Coord, let us assume that it is an extra conjunction in coordination that is headed by another conjunction.
                    $node->set_afun('AuxY');
                }
            }
            # There are possible conjuncts and we must identify them.
            else
            {
                $self->identify_coap_members($node);
            }
        }
        # Verb "je" labeled AuxX.
        elsif($node->form() eq 'je' && $node->afun() eq 'AuxX' && $parent->afun() eq 'Coord')
        {
            $node->set_afun('Pred');
            $node->set_is_member(1);
        }
        # Conjunction "akoby" labeled AuxY ("Lenže akoby sa díval na...")
        elsif($node->form() eq 'akoby' && $node->afun() eq 'AuxY' && $parent->afun() eq 'Coord')
        {
            $node->set_afun('AuxC');
            $node->set_is_member(1);
        }
        # Colon at sentence end, labeled Apos although there are no children.
        elsif($node->form() eq ':' && $node->afun() eq 'Apos' && $node->is_leaf())
        {
            $node->set_afun('AuxG');
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
sub guess_afun
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent(); ###!!! eparents? Akorát že ty závisí na správných afunech a rodič zatím taky nemusí mít správný afun.
    my $pos = $node->iset()->pos();
    my $ppos = $parent->iset()->pos();
    my $afun = 'NR';
    if($parent->is_root())
    {
        if($pos eq 'verb')
        {
            $afun = 'Pred';
        }
        elsif($node->form() eq 'ale' && grep {$_->afun() !~ m/^(Aux[GXY])$/} ($node->children()))
        {
            $afun = 'Coord';
            foreach my $child ($node->children())
            {
                if($child->afun() !~ m/^Aux[GXY]$/)
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
    elsif($parent->afun() eq 'Coord')
    {
        if($node->is_leaf() && $pos eq 'punc')
        {
            if($node->form() eq ',')
            {
                $afun = 'AuxX';
            }
            else
            {
                $afun = 'AuxG';
            }
        }
        else # probably conjunct
        {
            ###!!! We should look at the parent of the coordination and guess the function of the coordination.
            ###!!! Or figure out functions of other conjuncts if they have them.
            $afun = 'ExD';
            $node->set_is_member(1);
        }
    }
    # Preposition is always AuxP. The real function is tagged at its argument.
    elsif($pos eq 'adp')
    {
        $afun = 'AuxP';
    }
    elsif($parent->form() eq 'než')
    {
        # větší než já
        # V PDT se podobné fráze analyzují jako elipsa ("má větší příjem než [mám] já").
        $afun = 'ExD';
    }
    elsif($parent->form() eq 'ako')
    {
        # cien známych ako Kristián
        # V PDT se fráze se spojkou "jako" analyzují jako doplněk. Ovšem "jako" tam visí až na doplňku, čímž se liší od jiných výskytů podřadících spojek a předložek.
        $afun = 'Atv';
    }
    elsif($parent->form() eq 'že')
    {
        $afun = 'Obj';
    }
    elsif($ppos eq 'noun')
    {
        $afun = 'Atr';
    }
    elsif($node->is_foreign())
    {
        $afun = 'Atr';
    }
    elsif($ppos eq 'adj' && ($pos eq 'adj' || $node->iset()->prontype() ne ''))
    {
        $afun = 'Atr';
    }
    elsif($ppos eq 'num' && $pos eq 'noun') # example: viacero stredísk
    {
        $afun = 'Atr';
    }
    elsif($ppos eq 'verb')
    {
        my $case = $node->iset()->case();
        if($node->form() eq 'nie')
        {
            ###!!! This should be Neg but we should change it in all nodes, not just in those where we guess labels.
            $afun = 'Adv';
        }
        elsif($pos eq 'noun')
        {
            if($case eq 'nom')
            {
                $afun = 'Sb';
            }
            else
            {
                $afun = 'Obj';
            }
        }
        elsif($pos eq 'adj' && $case eq 'nom' && $parent->lemma() =~ m/^(ne)?byť$/)
        {
            $afun = 'Pnom';
        }
        elsif($pos eq 'verb') # especially infinitive
        {
            $afun = 'Obj';
        }
        elsif($pos eq 'adv')
        {
            $afun = 'Adv';
        }
        elsif($node->form() =~ m/^ak$/i)
        {
            $afun = 'AuxC';
        }
    }
    return $afun;
}

1;

=over

=item Treex::Block::HamleDT::SK::Harmonize

Converts SNK (Slovak National Corpus) trees to the HamleDT style. Currently
it only involves conversion of the morphological tags (and Interset decoding).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
