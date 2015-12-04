package Treex::Block::HamleDT::HarmonizePerseus;
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
    'OComp'     => 'Obj', ###!!! same as OCOMP; Index Thomisticus does not use all-capitals
    'PNOM'      => 'Pnom',
    'PRED'      => 'Pred',
    'SBJ'       => 'Sb',
    'UNDEFINED' => 'NR',
    # XSEG is assigned to initial parts of a broken word, e.g. "Achai - on": on ( Achai/XSEG , -/XSEG )
    'XSEG'      => 'Atr' ###!!! Should we add XSeg to the set of HamleDT labels?
);



#------------------------------------------------------------------------------
# Reads the Greek or Latin trees, decodes morphosyntactic tags and transforms
# the trees to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->remove_id_from_lemmas($root);
    $self->detect_proper_nouns($root);
    $self->fix_deficient_sentential_coordination($root);
    $self->fix_undefined_nodes($root);
    ###!!! TODO: grc trees sometimes have conjunct1, coordination, conjunct2 as siblings. We should fix it, but meanwhile we just delete afun=Coord from the coordination.
    $self->check_coord_membership($root);
    return $root;
}



#------------------------------------------------------------------------------
# Most lemmas contain numeric sense identifier. Remove the identifier from the
# lemma so that the lemma is only the base form of the word. Store the
# identifier in a wild attribute so that it can be output if desired.
#------------------------------------------------------------------------------
sub remove_id_from_lemmas
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $lemma = $node->lemma();
        if($form !~ m/\d$/ && $lemma =~ s/(\D)(\d+)/$1/)
        {
            $node->wild()->{lid} = $2;
            $node->set_lemma($lemma);
        }
    }
}



#------------------------------------------------------------------------------
# The Perseus tagsets do not distinguish proper nouns. Mark nouns as proper if
# their lemma is capitalized.
#------------------------------------------------------------------------------
sub detect_proper_nouns
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $iset = $node->iset();
        my $lemma = $node->lemma();
        if($iset->is_noun() && !$iset->is_pronoun())
        {
            if($lemma =~ m/^\p{Lu}/)
            {
                $iset->set('nountype', 'prop');
            }
            elsif($iset->nountype() eq '')
            {
                $iset->set('nountype', 'com');
            }
        }
    }
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
    # First loop: copy deprel to afun and convert _CO and _AP to is_member.
    # Leave everything else untouched until we know that is_member is set correctly for all nodes.
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun = $deprel;
        # There were occasional cycles in the source data. They were removed before importing the trees to Treex
        # but a mark was left in the dependency label where the cycle was broken.
        # Example: AuxP-CYCLE:12-CYCLE:16-CYCLE:15-CYCLE:14
        # We have no means of repairing the structure but we have to remove the mark in order to get a valid afun.
        $afun =~ s/-CYCLE.*//;
        # The _CO suffix signals conjuncts.
        # The _AP suffix signals members of apposition.
        # We will later reshape appositions but the routine will expect is_member set.
        if($afun =~ s/_(CO|AP)$//i)
        {
            $node->set_is_member(1);
            # There are nodes that have both _AP and _CO but we have no means of representing that.
            # Remove the other suffix if present.
            $afun =~ s/_(CO|AP)$//i;
        }
        # Convert the _PA suffix to the is_parenthesis_root flag.
        if($afun =~ s/_PA$//i)
        {
            $node->set_is_parenthesis_root(1);
        }
        $node->set_afun($afun);
    }
    # Second loop: process chained dependency labels and decide, what nodes are ExD, Coord, Apos, AuxP or AuxC.
    # At the same time translate the other afuns to the dialect of HamleDT.
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        # There are chained dependency labels that describe situation around elipsis.
        # They ought to contain an ExD, which may be indexed (e.g. ExD0).
        # The tag before ExD describes the dependency of the node on its elided parent.
        # The tag after ExD describes the dependency of the elided parent on the grandparent.
        # Example: ADV_ExD0_PRED_CO
        # Similar cases in PDT get just ExD.
        if($afun =~ m/ExD/)
        {
            # If the chained label is something like COORD_ExD0_OBJ_CO_ExD1_PRED,
            # this node should be Coord and the conjuncts should get ExD.
            # However, we still cannot set afun=ExD for the conjuncts.
            # This would involve traversing also AuxP nodes and nested Coord, so we need to have all Coords in place first.
            if($afun =~ m/^COORD/i)
            {
                $node->set_afun('Coord');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            elsif($afun =~ m/^APOS/i)
            {
                $node->set_afun('Apos');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            # Do not change AuxX and AuxG either.
            # These afuns reflect more what the node is than how it modifies its parent.
            elsif($afun =~ m/^(Aux[CPGX])/)
            {
                $node->set_afun($1);
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            else
            {
                $node->set_afun('ExD');
            }
        }
        # Most AGDT afuns are all uppercase but we typically want only the first letter uppercase.
        elsif(exists($agdt2pdt{$afun}))
        {
            $node->set_afun($agdt2pdt{$afun});
        }
        # AuxG cannot be conjunct in HamleDT but it happens in AGDT.
        if($node->afun() eq 'AuxG' && $node->is_member())
        {
            $node->set_is_member(undef);
        }
        # Try to fix inconsistencies in annotation of coordination.
        if($node->afun() !~ m/^(Coord|Apos)$/)
        {
            my @members = grep {$_->is_member()} ($node->children());
            if(scalar(@members)>0)
            {
                if($node->iset()->pos() =~ m/^(conj|punc|part|adv)$/)
                {
                    $node->set_afun('Coord');
                }
                else
                {
                    foreach my $member (@members)
                    {
                        $member->set_is_member(undef);
                    }
                }
            }
        }
    }
    # Third loop: we still cannot rely on is_member because it is not guaranteed that it is always set directly under COORD or APOS.
    # The source data follow the PDT convention that AuxP and AuxC nodes do not have it (and thus it is marked at a lower level).
    # In contrast, Treex marks is_member directly under Coord or Apos. We cannot convert it later because we need reliable is_member
    # for deprel conversion.
    foreach my $node (@nodes)
    {
        # no is_member allowed directly below root
        if ($node->is_member and $node->get_parent->is_root)
        {
            $node->set_is_member(0);
        }
        if($node->is_member())
        {
            my $new_member = $self->_climb_up_below_coap($node);
            if($new_member && $new_member != $node)
            {
                $new_member->set_is_member(1);
                $node->set_is_member(undef);
            }
        }
    }
    # Fourth loop: finish propagating ExD down the tree at coordination and apposition.
    foreach my $node (@nodes)
    {
        if($node->wild()->{'ExD conjuncts'})
        {
            # set_real_afun() goes down if it sees Coord, Apos, AuxP or AuxC
            $node->set_real_afun('ExD');
            delete($node->wild()->{'ExD conjuncts'});
        }
    }
    # Fix known annotation errors. They include coordination, i.e. the tree may now not be valid.
    # We should fix it now, before the superordinate class will perform other tree operations.
    $self->fix_annotation_errors($root);
}



#------------------------------------------------------------------------------
# Searches for the head of coordination or apposition in AGDT. Overrides the
# method from HarmonizePDT because of slightly different deprels in this
# treebank. Used for moving the is_member flag directly under the head (even if
# it is AuxP, in which case PDT would not put the flag there).
#------------------------------------------------------------------------------
sub _climb_up_below_coap
{
    my $self = shift;
    my $node = shift;
    if ($node->parent()->is_root())
    {
        log_warn('No co/ap node between a co/ap member and the tree root');
        return;
    }
    elsif ($node->parent()->afun() =~ m/(COORD|APOS)/i)
    {
        return $node;
    }
    else
    {
        return $self->_climb_up_below_coap($node->parent());
    }
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
        if($node->conll_deprel() eq 'UNDEFINED' && $node->deprel() ne 'AuxK' && $node->deprel() ne 'Coord')
        {
            if($node->parent()->is_root() && $node->is_leaf())
            {
                # Attach the node to the preceding token if there is a preceding token.
                if($i>0)
                {
                    $node->set_parent($nodes[$i-1]);
                }
                # If there is no preceding token but there is a following token, attach the node there.
                elsif($i<$#nodes && $nodes[$i+1]->deprel() ne 'AuxK')
                {
                    $node->set_parent($nodes[$i+1]);
                }
                # If this is the only token in the sentence, it remained attached to the root.
                # Pick the right deprel for the node.
                my $form = $node->form();
                if($form eq ',')
                {
                    $node->set_deprel('AuxX');
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
                    $node->set_deprel('AuxG');
                }
                else # neither punctuation nor diacritics
                {
                    $node->set_deprel('AuxY');
                }
            }
            # Other UNDEFINED nodes.
            elsif($node->parent()->is_root() && $node->is_verb())
            {
                $node->set_deprel('Pred');
            }
            elsif($node->parent()->is_root())
            {
                $node->set_deprel('ExD');
            }
            elsif(grep {$_->conll_deprel() eq 'XSEG'} ($node->get_siblings()))
            {
                # UNDEFINED nodes that are siblings of XSEG nodes should have been also XSEG nodes.
                $node->set_deprel('Atr');
            }
            elsif($node->parent()->is_noun())
            {
                $node->set_deprel('Atr');
            }
            elsif($node->parent()->is_verb() && $node->match_iset('pos' => 'noun', 'case' => 'acc'))
            {
                $node->set_deprel('Obj');
            }
            else
            {
                $node->set_deprel('ExD');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Deficient sentential coordination: coordinating conjunction at or near the
# beginning of the sentence, connects the main predicate with the predicate of
# the previous sentence (in theory). The conjunction should be child of the
# root and it should be labeled Coord. The main predicate should be its child,
# labeled Pred and is_member set (sometimes there are several children, marked
# Pred or ExD). Unfortunately in AGDT the conjunction is often labeled Pred
# instead of Coord (and morphologically it may be tagged as particle instead of
# conjunction).
#------------------------------------------------------------------------------
sub fix_deficient_sentential_coordination
{
    my $self = shift;
    my $root = shift;
    my @rchildren = $root->children();
    if(scalar(@rchildren)==2)
    {
        my $conjunction = $rchildren[0];
        if($conjunction->deprel() eq 'Pred' && grep {$_->is_member()} ($conjunction->children()))
        {
            $conjunction->set_deprel('Coord');
        }
    }
    # Sometimes the conjunction is leaf, attached to root and marked as Coord; the predicate(s) is(are) its sibling(s).
    if(scalar(@rchildren)>=2)
    {
        my $conjunction = $rchildren[0];
        if($conjunction->iset()->pos() =~ m/^(conj|part)$/ && $conjunction->deprel() eq 'Coord' && $conjunction->is_leaf())
        {
            my @predicates = grep {$_->deprel() eq 'Pred'} (@rchildren);
            if(scalar(@predicates)>=1)
            {
                foreach my $predicate (@predicates)
                {
                    $predicate->set_parent($conjunction);
                    $predicate->set_is_member(1);
                }
            }
            else
            {
                # We were not able to find any conjuncts for the conjunction.
                # Thus it must not be labeled Coord.
                $conjunction->set_deprel('ExD');
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
        my $deprel = $node->deprel();
        if($deprel eq 'Coord')
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
                if($node->form() eq ',')
                {
                    $node->set_deprel('AuxX');
                }
                elsif($node->is_punctuation())
                {
                    $node->set_deprel('AuxG');
                }
                elsif($parent->deprel() eq 'Coord' && $node->iset()->pos() =~ m/^(conj|part|adv)$/)
                {
                    $node->set_deprel('AuxY');
                }
            }
            # If there are children, are there conjuncts among them?
            elsif(scalar(grep {$_->is_member()} (@children))==0)
            {
                # Annotation error: quotation mark attached to comma.
                if(scalar(grep {$_->deprel() eq 'AuxG'} (@children))==scalar(@children))
                {
                    foreach my $child (@children)
                    {
                        # The child is punctuation. Attach it to the closest non-punctuation node.
                        # If it is now attached to the right, look for the parent on the right. Otherwise on the left.
                        if($child->ord()<$node->ord())
                        {
                            my @candidates = grep {$_->ord()>$child->ord() && $_->deprel() !~ m/^Aux[^C]/} (@nodes);
                            if(@candidates)
                            {
                                $child->set_parent($candidates[0]);
                            }
                        }
                        else
                        {
                            my @candidates = grep {$_->ord()<$child->ord() && $_->deprel() !~ m/^Aux[^C]/} (@nodes);
                            if(@candidates)
                            {
                                $child->set_parent($candidates[-1]);
                            }
                        }
                    }
                    if($node->form() eq ',')
                    {
                        $node->set_deprel('AuxX');
                    }
                    elsif($node->iset()->pos() eq 'punc')
                    {
                        $node->set_deprel('AuxG');
                    }
                }
                else
                {
                    $self->identify_coap_members($node);
                }
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::HarmonizePerseus

Common routines for conversion of the treebanks in the project Perseus
(Ancient Greek and Latin) to the style of HamleDT (Prague).
Syntactic tags (dependency relation labels) are mostly derived from PDT
but slight adjustments are necessary.

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
