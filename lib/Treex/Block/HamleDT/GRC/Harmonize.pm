package Treex::Block::HamleDT::GRC::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePDT';

my %agdt2pdt =
(
    'ADV'       => 'Adv',
    'APOS'      => 'Apos',
    'ATR'       => 'Atr',
    'ATV'       => 'Atv',
    'COORD'     => 'Coord',
    'OBJ'       => 'Obj',
    'OCOMP'     => 'Obj', ###!!!
    'PNOM'      => 'Pnom',
    'PRED'      => 'Pred',
    'SBJ'       => 'Sb',
    'UNDEFINED' => 'NR',
    # XSEG is assigned to initial parts of a broken word, e.g. "Achai - on": on ( Achai/XSEG , -/XSEG )
    'XSEG'      => 'Atr' ###!!! Should we add XSeg to the set of HamleDT labels?
);

#------------------------------------------------------------------------------
# Reads the Ancient Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fix_undefined_nodes($root);
    ###!!! TODO: grc trees sometimes have conjunct1, coordination, conjunct2 as siblings. We should fix it, but meanwhile we just delete afun=Coord from the coordination.
    $self->check_coord_membership($root);
    $self->check_afuns($root);
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
        # There were occasional cycles in the source data. They were removed before importing the trees to Treex
        # but a mark was left in the dependency label where the cycle was broken.
        # Example: AuxP-CYCLE:12-CYCLE:16-CYCLE:15-CYCLE:14
        # We have no means of repairing the structure but we have to remove the mark in order to get a valid afun.
        $afun =~ s/-CYCLE.*//;
        # The _CO suffix signals conjuncts.
        # The _AP suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($afun =~ s/_(CO|AP)$//)
        {
            $node->set_is_member(1);
            # There are nodes that have both _AP and _CO but we have no means of representing that.
            # Remove the other suffix if present.
            $afun =~ s/_(CO|AP)$//;
        }
        # Convert the _PA suffix to the is_parenthesis_root flag.
        if($afun =~ s/_PA$//)
        {
            $node->set_is_parenthesis_root(1);
        }
        # There are chained dependency labels that describe situation around elipsis.
        # They ought to contain an ExD, which may be indexed.
        # The tag before ExD describes the dependency of the node on its elided parent.
        # The tag after ExD describes the dependency of the elided parent on the grandparent.
        # Example: ADV_ExD0_PRED_CO
        # Similar cases in PDT get just ExD.
        if($afun =~ m/ExD/)
        {
            $afun = 'ExD';
        }
        # Most AGDT afuns are all uppercase but we typically want only the first letter uppercase.
        if(exists($agdt2pdt{$afun}))
        {
            $afun = $agdt2pdt{$afun};
        }
        $node->set_afun($afun);
    }
    foreach my $node (@nodes)
    {
        # "and" and "but" have often deprel PRED
        if ($node->form =~ /^(και|αλλ’|,)$/ and grep {$_->is_member} $node->get_children) {
            $node->set_afun("Coord");
        }

        # no is_member allowed directly below root
        if ($node->is_member and $node->get_parent->is_root) {
            $node->set_is_member(0);
        }

    }
    # Coordination of prepositional phrases or subordinate clauses:
    # In PDT, is_member is set at the node that bears the real afun. It is not set at the AuxP/AuxC node.
    # In HamleDT (and in Treex in general), is_member is set directly at the child of the coordination head (preposition or not).
    $self->get_or_load_other_block('HamleDT::Pdt2TreexIsMemberConversion')->process_zone($root->get_zone());
}

#------------------------------------------------------------------------------
# A few punctuation nodes (commas and dashes) are attached non-projectively to
# the root, ignoring their neighboring tokens. They are labeled with the
# UNDEFINED afun (which we temporarily converted to NR). Attach them to the
# preceding token and give them a better afun.
#------------------------------------------------------------------------------
sub fix_undefined_nodes
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        # If this is the last punctuation in the sentence, chances are that it was already recognized as AuxK.
        # In that case the problem is already fixed.
        if($node->conll_deprel() eq 'UNDEFINED')
        {
            if($node->parent()->is_root() && $node->is_leaf() && $node->afun() ne 'AuxK')
            {
                # Attach the node to the preceding token if there is a preceding token.
                if($i>0)
                {
                    $node->set_parent($nodes[$i-1]);
                }
                # If there is no preceding token but there is a following token, attach the node there.
                elsif($i<$#nodes)
                {
                    $node->set_parent($nodes[$i+1]);
                }
                # If this is the only token in the sentence, it remained attached to the root.
                # Pick the right afun for the node.
                my $form = $node->form();
                if($form eq ',')
                {
                    $node->set_afun('AuxX');
                }
                # Besides punctuation there are also separated diacritics that should never appear alone in a node but they do:
                # 768 \x{300} COMBINING GRAVE ACCENT
                # 769 \x{301} COMBINING ACUTE ACCENT
                # 787 \x{313} COMBINING COMMA ABOVE
                # 788 \x{314} COMBINING REVERSED COMMA ABOVE
                # 803 \x{323} COMBINING DOT BELOW
                # 834 \x{342} COMBINING GREEK PERISPOMENI
                # All these characters belong to the class M (marks).
                elsif($form =~ m/^[\pP\pM]+$/)
                {
                    $node->set_afun('AuxG');
                }
                else # neither punctuation nor diacritics
                {
                    $node->set_afun('AuxY');
                }
            }
            # Other UNDEFINED nodes.
            elsif($node->parent()->is_root() && $node->get_iset('pos') eq 'verb')
            {
                $node->set_afun('Pred');
            }
            elsif($node->parent()->is_root())
            {
                $node->set_afun('ExD');
            }
            elsif(grep {$_->conll_deprel() eq 'XSEG'} ($node->get_siblings()))
            {
                # UNDEFINED nodes that are siblings of XSEG nodes should have been also XSEG nodes.
                $node->set_afun('Atr');
            }
        }
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
                ###!!! TODO
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

=item Treex::Block::HamleDT::GRC::Harmonize

Converts Ancient Greek dependency treebank to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions but they are very elaborated
so we have shortened them.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
