package Treex::Block::HamleDT::EL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'el::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    # Error handling routines
    $self->remove_ismember_membership($root);
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
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        # Convert _Co and _Ap suffixes to the is_member flag.
        if($deprel =~ s/_(Co|Ap)$//)
        {
            $node->set_is_member(1);
        }
        # Convert the _Pa suffix to the is_parenthesis_root flag.
        if($deprel =~ s/_Pa$//)
        {
            $node->set_is_parenthesis_root(1);
        }
        # HamleDT currently does not distinguish direct and indirect objects.
        $deprel =~ s/^IObj/Obj/;
        if ( $deprel eq '---' )
        {
            $deprel = "Atr";
        }
        # combined deprels (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $deprel =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $deprel = 'Atr';
        }
        $node->set_deprel($deprel);
    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real deprel. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->pdt_to_treex_is_member_conversion($root);
}

#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies. If there are no conjuncts under
# a Coord node, let's try to find them; same for Apos. This method is called
# from the superordinate class before any tree transformations occur (in
# particular before coordination is analyzed).
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if($deprel =~ m/^(Coord|Apos)$/)
        {
            my @children = $node->children();
            # Are there any children?
            if(scalar(@children)==0)
            {
                # There are a few annotation errors where a leaf node is labeled Coord.
                # In some cases, the node is rightly Coord but it ought not to be leaf.
                my $parent = $node->parent();
                my $sibling = $node->get_left_neighbor();
                my $uncle = $parent->get_left_neighbor();
                if($parent->deprel() eq 'Pred' && defined($sibling) && $sibling->deprel() eq 'Pred')
                {
                    $node->set_parent($parent->parent());
                    $sibling->set_parent($node);
                    $sibling->set_is_member(1);
                    $parent->set_parent($node);
                    $parent->set_is_member(1);
                }
                elsif($parent->deprel() eq 'Pred' && defined($uncle)) # $uncle->deprel() eq 'ExD' but it is a verb
                {
                    $node->set_parent($parent->parent());
                    $uncle->set_parent($node);
                    $uncle->set_deprel('Pred');
                    $uncle->set_is_member(1);
                    $parent->set_parent($node);
                    $parent->set_is_member(1);
                }
                elsif($node->is_leaf() && $node->get_iset('pos') eq 'conj')
                {
                    $node->set_deprel('AuxY');
                }
                elsif($node->is_leaf() && $node->get_iset('pos') eq 'noun')
                {
                    $node->set_deprel('Atr');
                }
            }
            # If there are children, are there conjuncts among them?
            elsif(scalar(grep {$_->is_member()} (@children))==0)
            {
                $self->identify_coap_members($node);
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::EL::Harmonize

Converts Modern Greek dependency treebank into the style of HamleDT (Prague).

1. Morphological conversion             -> Yes

2. DEPREL conversion                    -> Yes

3. Structural conversion to match PDT   -> Yes



=back

=cut

# Copyright 2011, 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
