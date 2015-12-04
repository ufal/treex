package Treex::Block::HamleDT::SL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'sl::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Slovene tree, converts morphosyntactic tags to the PDT tagset,
# converts deprels, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->change_wrong_puctuation_root($root);
    $self->change_quotation_predicate_into_obj($root);
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
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $deprel =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $deprel = 'Atr';
        }
        # There are a few nodes wrongly labeled as Coord. Fix them.
        # We must do it now, before SUPER->restructure_coordination() starts.
        # And also before we try to reconstruct members of coordination (comma/Coord must become comma/AuxX where appropriate).
        if($deprel eq 'Coord')
        {
            my @children = $node->children();
            if($node->form() eq ',' && $node->is_leaf())
            {
                $deprel = 'AuxX';
            }
            elsif($node->form() eq 'In' && $node->is_leaf() && $node->parent()->is_root())
            {
                # In theory there could be more than one verb but we are addressing a single known annotation error here.
                my $verb = $node->get_right_neighbor();
                if(defined($verb) && $verb->is_verb())
                {
                    $verb->set_parent($node);
                    $verb->set_is_member(1);
                }
            }
            # Pa vendar - !
            # And yet - !
            elsif(lc($node->form()) eq 'pa' && $node->parent()->is_root() &&
                  (
                      $node->is_leaf() ||
                      scalar(@children)==2 && lc($children[0]->form()) eq 'vendar' && !$children[1]->is_verb()
                  ))
            {
                $deprel = 'ExD';
            }
        }
        # Unlike the CoNLL conversion of the Czech PDT 2.0, the Slovenes don't mark coordination members.
        # (They do in their original data format but the information has not been ported to CoNLL!)
        # I suspect (but I am not sure) that they always attach coordination modifiers to a member,
        # so there are no shared modifiers and all children of Coord are members. Let's start with this hypothesis.
        # We cannot query parent's deprel because it may not have been copied from conll_deprel yet.
        my $pdeprel = $node->parent()->conll_deprel();
        $pdeprel = '' if ( !defined($pdeprel) );
        if ($pdeprel =~ m/^(Coord|Apos)$/
            &&
            $deprel !~ m/^(Aux[GKXY])$/
            )
        {
            $node->set_is_member(1);
        }
        # Set the (possibly changed) deprel back to the node.
        $node->set_deprel($deprel);
    }
}

#------------------------------------------------------------------------------
# For some reason, punctuation right before coordinations are not dependent
# on the conjunction, but on the very root of the tree. I will make sure they
# are dependent correctly on the following word, which is the conjunction.
#------------------------------------------------------------------------------
sub change_wrong_puctuation_root
{
    my $self = shift;
    my $root = shift;
    my @children = $root->get_children();
    if (scalar @children>2)
    {
        # I am not taking the last one
        for my $child (@children[0..$#children-1])
        {
            if ($child->deprel() =~ /^Aux[XG]$/ && $child->is_leaf())
            {
                my $conjunction = $child->get_next_node();
                if (defined($conjunction) && $conjunction->is_conjunction())
                {
                    $child->set_parent($conjunction);
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Quotations should have Obj as predicate, but here, they have Adj. I have to
# switch them.
#------------------------------------------------------------------------------
sub change_quotation_predicate_into_obj
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    for my $node (@nodes)
    {
        my @children = $node->get_children();
        my $has_quotation_dependent = 0;
        for my $child (@children)
        {
            if ($child->form eq q{"})
            {
                if ($node->deprel() eq 'Adv')
                {
                    $node->set_deprel('Obj');
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::SL::Harmonize

Converts SDT (Slovene Dependency Treebank) trees from CoNLL to the style of
HamleDT (Prague). The structure of the trees should already
adhere to the PDT guidelines because SDT has been modeled after PDT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to deprel. Morphological tags will be
decoded into Interset and converted to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011, 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2012 Karel Bilek <kb@karelbilek.com>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
