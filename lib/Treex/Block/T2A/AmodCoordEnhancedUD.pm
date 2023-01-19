package Treex::Block::T2A::AmodCoordEnhancedUD;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



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
# node so that it is more natural with respect to the adjective.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $document = $zone->get_document();
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
        next if(!$tnode->is_member());
        # Get the corresponding a-node. Remember: $tnode->get_lex_anode()
        # always refers to a regular node in the basic UD tree; there may be
        # multiple t-nodes pointing to the same lexical a-node (in our case,
        # both the overt noun and its generated copy will point to the same
        # a-node). In contrast, $tnode->wild()->{'anode.rf'} is our addition.
        # For most t-nodes it still returns the lexical a-node as above, but
        # for generated t-nodes it returns the corresponding empty a-node that
        # we created in the block T2A::GenerateEmptyNodes.
        my $anode = $document->get_node_by_id($tnode->wild()->{'anode.rf'});
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
        # We should not use this method for verbs. It would apply to numerous
        # instances of gapping, which should be solved eventually, but differently.
        next if(!$anode->is_noun());
        my @eparents = $anode->get_enhanced_parents();
        next if(scalar(@eparents) != 1);
        my $overt_noun = $eparents[0];
        # We assume that the a-node corresponding to this conjunct is attached
        # as nmod to the a-node that corresponds to the other conjunct, which
        # is overtly represented on the surface. Hence the parent in the a-tree
        # should have the same form.
        next if($overt_noun->form() ne $anode->form());
        # Does the corresponding t-node have children (such as the adjective)?
        my @tchildren = $tnode->get_children();
        next if(scalar(@tchildren) == 0);
        # We will need the a-nodes that correspond to the t-children.
        my @achildren = Treex::Core::Node::A::sort_nodes_by_conllu_ids(grep {defined($_)} (map {$document->get_node_by_id($_->wild()->{'anode.rf'})} (@tchildren)));
        next if(scalar(@achildren) == 0);
        ###!!! I don't have an example with multiple @achildren. It should be
        ###!!! possible to process but it would be more difficult to identify
        ###!!! the head, so let's assume for now that there is just one a-child.
        next if(scalar(@achildren) > 1);
        # This child should be the first conjunct and should be attached to the
        # parent of the coordination. The overt noun should be attached to it
        # as conj.
        my @conj_parents_of_overt_noun = $overt_noun->get_enhanced_parents('^conj(:|$)');
        next if(scalar(@conj_parents_of_overt_noun) != 1);
        next if($conj_parents_of_overt_noun[0] != $achildren[0]);
        # The current empty node will be the new head of the first conjunct.
        # This block should be run after A2A::CopyBasicToEnhancedUD and before
        # A2A::AddEnhancedUD, so there should be just one incoming enhanced
        # edge. But if there are more, remove all of them.
        $anode->set_enhanced_deps($achildren[0]->get_enhanced_deps());
        my $edeprel = $self->guess_modifier_deprel($achildren[0]);
        $achildren[0]->clear_enhanced_deps();
        $achildren[0]->add_enhanced_dependency($anode, $edeprel);
        # If the child had functional children, re-attach them to the copied noun.
        for my $grandchild ($achildren[0]->get_enhanced_children('^((case|cc|punct)(:|$)|advmod:emph)'))
        {
            $grandchild->clear_enhanced_deps();
            $grandchild->add_enhanced_dependency($anode, $grandchild->is_empty() ? $self->guess_modifier_deprel($grandchild) : $grandchild->deprel());
        }
        # The overt noun is the second conjunct and it should now be attached
        # directly to the copied noun instead of its overt child.
        $overt_noun->clear_enhanced_deps();
        $overt_noun->add_enhanced_dependency($anode, 'conj');
        # Adjust the linear position of the copied a-node so that it immediately
        # follows its rightmost child (assuming the child is an adjective and the
        # language is Czech, this should be a naturally sounding position).
        $anode->shift_empty_node_after_node($achildren[-1]);
    }
    $aroot->_normalize_ords_and_conllu_ids();
}



#------------------------------------------------------------------------------
# Guesses the UD deprel for a modifier of a noun, depending on the part of
# speech of the modifier.
#------------------------------------------------------------------------------
sub guess_modifier_deprel
{
    my $self = shift;
    my $achild = shift;
    my $edeprel = 'dep';
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
    elsif($achild->is_adverb() || $achild->is_particle())
    {
        $edeprel = 'advmod:emph';
    }
    elsif($achild->is_adposition() || $achild->is_subordinator())
    {
        $edeprel = 'case';
    }
    elsif($achild->is_coordinator())
    {
        $edeprel = 'cc';
    }
    elsif($achild->is_interjection())
    {
        $edeprel = 'discourse';
    }
    elsif($achild->is_punctuation())
    {
        $edeprel = 'punct';
    }
    else
    {
        $edeprel = 'nmod';
    }
    return $edeprel;
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
