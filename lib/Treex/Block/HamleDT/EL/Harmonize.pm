package Treex::Block::HamleDT::EL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

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
    $self->check_coord_membership($root);
    $self->remove_ismember_membership($root);
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
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $form   = $node->form();
        my $pos    = $node->conll_pos();
        # default assignment
        my $afun = $deprel;
        # Convert _Co and _Ap suffixes to the is_member flag.
        if($afun =~ s/_(Co|Ap)$//)
        {
            $node->set_is_member(1);
        }
        # Convert the _Pa suffix to the is_parenthesis_root flag.
        if($afun =~ s/_Pa$//)
        {
            $node->set_is_parenthesis_root();
        }
        # HamleDT currently does not distinguish direct and indirect objects.
        $afun =~ s/^IObj/Obj/;
        if ( $deprel eq '---' ) {
            $afun = "Atr";
        }
        # combined afuns (AtrAtr, AtrAdv, AdvAtr, AtrObj, ObjAtr)
        if ( $afun =~ m/^((Atr)|(Adv)|(Obj))((Atr)|(Adv)|(Obj))/ )
        {
            $afun = 'Atr';
        }
        $node->set_afun($afun);
    }
}

#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies. If there are no conjuncts under
# a Coord node, let's try to find them. (We do not care about apposition
# because it has been restructured.)
#------------------------------------------------------------------------------
sub check_coord_membership
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if($afun eq 'Coord')
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
                if($parent->afun() eq 'Pred' && defined($sibling) && $sibling->afun() eq 'Pred')
                {
                    $node->set_parent($parent->parent());
                    $sibling->set_parent($node);
                    $sibling->set_is_member(1);
                    $parent->set_parent($node);
                    $parent->set_is_member(1);
                }
                elsif($parent->afun() eq 'Pred' && defined($uncle)) # $uncle->afun() eq 'ExD' but it is a verb
                {
                    $node->set_parent($parent->parent());
                    $uncle->set_parent($node);
                    $uncle->set_afun('Pred');
                    $uncle->set_is_member(1);
                    $parent->set_parent($node);
                    $parent->set_is_member(1);
                }
                elsif($node->is_leaf() && $node->get_iset('pos') eq 'conj')
                {
                    $node->set_afun('AuxY');
                }
                elsif($node->is_leaf() && $node->get_iset('pos') eq 'noun')
                {
                    $node->set_afun('Atr');
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

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
