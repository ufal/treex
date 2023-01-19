package Treex::Block::T2A::AmodCoordEnhancedUD;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    my @tnodes = $troot->get_descendants({ordered => 1});
    my @anodes = $aroot->get_descendants({ordered => 1});
    foreach my $tnode (@tnodes)
    {
        # This block focuses on generated t-nodes, i.e. those that have to be
        # represented as empty nodes in UD (if represented at all).
        next if(!$tnode->is_generated());
        # Is the corresponding t-node a member of coordination or apposition?
        # Note: In the future we may find out that a similar procedure is needed
        # for other constructions that are not coordination or apposition. But for
        # now let's stick to the prototypical situation.
        return if(!$tnode->is_member());
        # Get the corresponding a-node.
        my $anode = $tnode->get_lex_anode();
        # Sanity checks: We expect the a-node to be empty and to refer back to
        # this t-node. That means that the lex_anode reference at the t-node
        # was updated once the empty a-node was created; originally it lead to
        # the source node on the surface from both the t-nodes.
        if($anode->wild()->{'tnode.rf'} ne $tnode->id())
        {
            log_fatal(sprintf("T-node '%s' refers to lex a-node '%s', which refers to a different t-node '%s'.", $tnode->id(), $anode->id(), $anode->wild()->{'tnode.rf'}));
        }
        if(!$anode->is_empty())
        {
            log_fatal(sprintf("Generated t-node '%s' refers to lex a-node '%s', which is not empty.", $tnode->id(), $anode->id()));
        }
        # Make sure we can access the t-node from the new a-node and vice versa.
        #$anode->wild()->{'tnode.rf'} = $tnode->id();
        #$tnode->wild()->{'anode.rf'} = $anode->id();
        # Extra adjustments for generated nodes that are copies of conjuncts in coordination.
        $self->adjust_copied_conjunct($anode, $tnode);
    }
    $aroot->_normalize_ords_and_conllu_ids();
}



#------------------------------------------------------------------------------
# Adjusts the structural position of an empty node that is a copy of a noun in
# coordination, whereas there is coordination of adjectival modifiers on the
# surface. Example: "akcí pro domácí (turisty) i cizí turisty". The copied node
# was generated as a leaf but we want the corresponding adjective re-attached
# to it in the enhanced graph. Also, the copied node is now probably attached
# to the source/surface conjunct as nmod. If the source conjunct happens to be
# the first conjunct, we only have to relabel the relation to conj. But if the
# source conjunct is not the first one, we must also restructure the coordina-
# tion. Before that, we may want to adjust the linear position of the copied
# node so that it is more natural with respect to the adjective; therefore,
# this method should be called after the generic position_empty_node().
#------------------------------------------------------------------------------
sub adjust_copied_conjunct
{
    my $self = shift;
    my $copy_anode = shift;
    my $copy_tnode = shift;
    my $document = $copy_anode->get_document();
    # We should not use this method for verbs. It would apply to numerous
    # instances of gapping, which should be solved eventually, but differently.
    return if(!$copy_anode->is_noun());
    # Does the corresponding t-node have children (such as the adjective)?
    my @tchildren = $copy_tnode->get_children();
    return if(scalar(@tchildren) == 0);
    # We will need the a-nodes that correspond to the t-children. Typically,
    # the children are represented on the surface and their a-nodes exist.
    # However, if we also want to process generated children, we should move
    # this method to a separate block and call it after the current block has
    # finished generating empty nodes for all generated t-nodes.
    my @achildren = Treex::Core::Node::A::sort_nodes_by_conllu_ids(grep {defined($_)} (map {$_->get_lex_anode()} (@tchildren)));
    return if(scalar(@achildren) == 0);
    # Re-attach the children to the copied a-node in the enhanced graph.
    foreach my $achild (@achildren)
    {
        # This should not lead to self-loops but double check.
        next if($achild == $copy_anode);
        # This block should be run after A2A::CopyBasicToEnhancedUD and before
        # A2A::AddEnhancedUD, so there should be just one incoming enhanced
        # edge. But if there are more, remove all of them.
        $achild->clear_enhanced_deps();
        my $edeprel = 'dep';
        if($copy_anode->is_noun())
        {
            if($achild->is_determiner())
            {
                $edeprel = 'det';
            }
            elsif($achild->is_cardinal())
            {
                $edeprel = 'nummod';
            }
            elsif($achild->is_adjective())
            {
                $edeprel = 'amod';
            }
            elsif($achild->is_verb())
            {
                $edeprel = 'acl';
            }
            else
            {
                $edeprel = 'nmod';
            }
        }
        $achild->add_enhanced_dependency($copy_anode, $edeprel);
    }
    # Adjust the linear position of the copied a-node so that it immediately
    # follows its rightmost child (assuming the child is an adjective and the
    # language is Czech, this should be a naturally sounding position).
    $copy_anode->shift_empty_node_after_node($achildren[-1]);
    # The copied a-node should be attached to its parent as conj. But if it
    # precedes it in the linear order, the relation should have the opposite
    # direction.
    my @eparents = $copy_anode->get_enhanced_parents();
    if(scalar(@eparents) == 1)
    {
        my $eparent = $eparents[0];
        my $cmp = Treex::Core::Node::A::cmp_conllu_ids($copy_anode->get_conllu_id(), $eparent->get_conllu_id());
        if($cmp < 0)
        {
            # The copied node precedes its parent. We must swap the parent and
            # the child so that all conj relations go left-to-right.
            $copy_anode->set_enhanced_deps($eparent->get_enhanced_deps());
            $eparent->clear_enhanced_deps();
            $eparent->add_enhanced_dependency($copy_anode, 'conj');
        }
        else # no redirecting, just setting the edeprel
        {
            $copy_anode->clear_enhanced_deps();
            $copy_anode->add_enhanced_dependency($eparent, 'conj');
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::AmodCoordEnhancedUD

=item DESCRIPTION

If a noun is modified by a coordination of adjectives (or other modifiers) in
the a-tree, the corresponding t-tree will have a generated copy of the noun,
coordinated with the original surface noun, and the modifiers will be
distributed to their copies of the noun. Example: "jde nikoliv o neschopné,
ale o nemotivované zaměstnance" ("one speaks not about incapable but about
unmotivated employees"). A-tree: Coord(jde, ale); AuxP_Co(ale, o-3);
AuxP_Co(ale, o-6); ExD(o-3, neschopné); ExD(o-6, zaměstnance); Atr(zaměstnance,
nemotivované). T-tree: ADVS(jde, ale); ACT.member(ale, o zaměstnance-COPY);
ACT.member(ale, o zaměstnance); RSTR(o zaměstnance-COPY, neschopné);
RSTR(o zaměstnance, nemotivované).

This block projects the t-tree to the enhanced UD graph. It assumes that the
a-tree has already been converted to UD (block HamleDT::Udep) and, additionally,
that there are empty nodes corresponding to the generated t-nodes (block
T2A::GenerateEmptyNodes). Nevertheless, the structural and linear position of
the empty nodes is only estimated or random, and this block will attempt to
fix it.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
