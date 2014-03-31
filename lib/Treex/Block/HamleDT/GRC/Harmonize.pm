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
    $self->fix_deficient_sentential_coordination($root);
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
            if($afun =~ m/^COORD/)
            {
                $node->set_afun('Coord');
                $node->wild()->{'ExD conjuncts'} = 1;
            }
            elsif($afun =~ m/^APOS/)
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
                if($node->get_iset('pos') =~ m/^(conj|punc|part|adv)$/)
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
    # for afun conversion. And we cannot use the Pdt2TreexIsMemberConversion block because it relies on the afuns Coord and Apos
    # and these are not yet ready.
    foreach my $node (@nodes)
    {
        # no is_member allowed directly below root
        if ($node->is_member and $node->get_parent->is_root)
        {
            $node->set_is_member(0);
        }
        if($node->is_member())
        {
            my $new_member = _climb_up_below_coap($node);
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
# Searches for the head of coordination or apposition in AGDT. Adapted from
# Pdt2TreexIsMemberConversion by Zdeněk Žabokrtský (but different because of
# slightly different afuns in this treebank). Used for moving the is_member
# flag directly under the head (even if it is AuxP, in which case PDT would not
# put the flag there).
#------------------------------------------------------------------------------
sub _climb_up_below_coap
{
    my ($node) = @_;
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
        return _climb_up_below_coap($node->parent());
    }
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
        # Coord is leaf or its children are not conjuncts.
        if($node->afun() eq 'Coord' && scalar(grep {$_->is_member()} (@children))==0)
        {
            # Deficient sentential coordination: conjunctless Coord is child of root.
            if($parent->is_root())
            {
                my @conjuncts = grep {$_ != $node && $_->afun() =~ m/^(Pred|ExD|Coord|Apos|AuxP|AuxC|Adv)$/} ($parent->children());
                if(@conjuncts)
                {
                    # Loop over all children, not just conjuncts. If there are delimiters, they must be attached as well.
                    foreach my $child ($parent->children())
                    {
                        next if($child==$node);
                        # If this function is called from deprel_to_afun(), attachment of sentence-final punctuation will be assessed later.
                        # Thus we do not need to check whether the node we are modifying is or is not AuxK.
                        $child->set_parent($node);
                        if($child->afun() !~ m/^(Coord|Apos)$/ && $child->form() eq ',')
                        {
                            $child->set_afun('AuxX');
                        }
                        else
                        {
                            if($child->afun() eq 'Adv')
                            {
                                $child->set_afun('ExD');
                            }
                            $child->set_is_member(1);
                        }
                    }
                }
            }
            elsif($node->is_leaf())
            {
                # Comma + coordinating conjunctin/particle. Coordination headed by the
                # comma, the conjunction attached as leaf several levels down, but it
                # is labeled Coord.
                # Is it a conjunction or a particle?
                if($node->get_iset('pos') =~ m/^(conj|part)$/)
                {
                    # Is the preceding token comma, labeled as Coord?
                    my $previous = $node->get_prev_node();
                    if($previous && $previous->form() eq ',' && $previous->afun() eq 'Coord')
                    {
                        my $conjunction = $node;
                        my $comma = $previous;
                        # Attach the conjunction where the comma was attached.
                        my $parent = $comma->parent();
                        $conjunction->set_parent($parent);
                        if($comma->is_member())
                        {
                            $conjunction->set_is_member(1);
                        }
                        # Attach all children of the comma (conjuncts, shared modifiers and delimiters) to the conjunction.
                        # They will keep their current afuns and is_member values.
                        foreach my $child ($comma->children())
                        {
                            $child->set_parent($conjunction);
                        }
                        # Attach the comma to the conjunction.
                        $comma->set_parent($conjunction);
                        $comma->set_afun('AuxX');
                        $comma->set_is_member(undef);
                    }
                    else # this is conj or part, preceding node is not coordinating comma
                    {
                        # Two subjects followed by the particle "te", all attached as siblings.
                        my @preceding_tokens = grep {$_->ord() < $node->ord()} (@nodes);
                        if(scalar(@preceding_tokens)>=2 &&
                        $preceding_tokens[$#preceding_tokens]->parent()==$parent &&
                        $preceding_tokens[$#preceding_tokens-1]->parent()==$parent &&
                        $preceding_tokens[$#preceding_tokens]->afun() eq $preceding_tokens[$#preceding_tokens-1]->afun())
                        {
                            $preceding_tokens[$#preceding_tokens]->set_parent($node);
                            $preceding_tokens[$#preceding_tokens]->set_is_member(1);
                            $preceding_tokens[$#preceding_tokens-1]->set_parent($node);
                            $preceding_tokens[$#preceding_tokens-1]->set_is_member(1);
                        }
                        # A strange combination of prepositional phrases and coordinating elements: o d' es te Pytho kapi Dodonis pyknous theopropous iallen
                        elsif($node->get_right_neighbor()->afun() eq 'Coord')
                        {
                            $node->set_parent($node->get_right_neighbor());
                            $node->set_afun('AuxY');
                        }
                        # Deficient sentential coordination.
                        elsif($parent eq 'Pred')
                        {
                            my $grandparent = $parent->parent();
                            $node->set_parent($grandparent);
                            $parent->set_parent($node);
                            $parent->set_is_member(1);
                        }
                        else
                        {
                            $node->set_afun('AuxY');
                        }
                    }
                }
                # Shared modifier of upper-level coordination.
                elsif($node->get_iset('pos') eq 'adj' && $node->parent()->afun() eq 'Coord')
                {
                    my @eparents = grep {$_->is_member()} ($node->parent()->children());
                    if(@eparents && $eparents[0]->get_iset('pos') eq 'noun')
                    {
                        $node->set_afun('Atr');
                    }
                }
            } # if Coord is_leaf
            # Coord is not leaf but there are no conjuncts among its children.
            else
            {
                if(scalar(@children)==1 && $children[0]->afun() eq 'AuxY' && $parent->afun() eq 'Coord')
                {
                    # Both this node and its child are secondary conjunctions of a larger coordination.
                    $node->set_afun('AuxY');
                    $children[0]->set_parent($parent);
                }
            }
        }
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
        if($node->conll_deprel() eq 'UNDEFINED' && $node->afun() ne 'AuxK' && $node->afun() ne 'Coord')
        {
            if($node->parent()->is_root() && $node->is_leaf())
            {
                # Attach the node to the preceding token if there is a preceding token.
                if($i>0)
                {
                    $node->set_parent($nodes[$i-1]);
                }
                # If there is no preceding token but there is a following token, attach the node there.
                elsif($i<$#nodes && $nodes[$i+1]->afun() ne 'AuxK')
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
            elsif($node->parent()->get_iset('pos') eq 'noun')
            {
                $node->set_afun('Atr');
            }
            elsif($node->parent()->get_iset('pos') eq 'verb' && $node->match_iset('pos' => 'noun', 'case' => 'acc'))
            {
                $node->set_afun('Obj');
            }
            else
            {
                $node->set_afun('ExD');
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
        if($conjunction->afun() eq 'Pred' && grep {$_->is_member()} ($conjunction->children()))
        {
            $conjunction->set_afun('Coord');
        }
    }
    # Sometimes the conjunction is leaf, attached to root and marked as Coord; the predicate(s) is(are) its sibling(s).
    if(scalar(@rchildren)>=2)
    {
        my $conjunction = $rchildren[0];
        if($conjunction->get_iset('pos') =~ m/^(conj|part)$/ && $conjunction->afun() eq 'Coord' && $conjunction->is_leaf())
        {
            my @predicates = grep {$_->afun() eq 'Pred'} (@rchildren);
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
                $conjunction->set_afun('ExD');
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
                if($node->form() eq ',')
                {
                    $node->set_afun('AuxX');
                }
                elsif($node->get_iset('pos') eq 'punc')
                {
                    $node->set_afun('AuxG');
                }
                elsif($parent->afun() eq 'Coord' && $node->get_iset('pos') =~ m/^(conj|part|adv)$/)
                {
                    $node->set_afun('AuxY');
                }
            }
            # If there are children, are there conjuncts among them?
            elsif(scalar(grep {$_->is_member()} (@children))==0)
            {
                # Annotation error: quotation mark attached to comma.
                if(scalar(grep {$_->afun() eq 'AuxG'} (@children))==scalar(@children))
                {
                    foreach my $child (@children)
                    {
                        # The child is punctuation. Attach it to the closest non-punctuation node.
                        # If it is now attached to the right, look for the parent on the right. Otherwise on the left.
                        if($child->ord()<$node->ord())
                        {
                            my @candidates = grep {$_->ord()>$child->ord() && $_->afun() !~ m/^Aux[^C]/} (@nodes);
                            if(@candidates)
                            {
                                $child->set_parent($candidates[0]);
                            }
                        }
                        else
                        {
                            my @candidates = grep {$_->ord()<$child->ord() && $_->afun() !~ m/^Aux[^C]/} (@nodes);
                            if(@candidates)
                            {
                                $child->set_parent($candidates[-1]);
                            }
                        }
                    }
                    if($node->form() eq ',')
                    {
                        $node->set_afun('AuxX');
                    }
                    elsif($node->get_iset('pos') eq 'punc')
                    {
                        $node->set_afun('AuxG');
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

=item Treex::Block::HamleDT::GRC::Harmonize

Converts Ancient Greek dependency treebank to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions but they are very elaborated
so we have shortened them.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
