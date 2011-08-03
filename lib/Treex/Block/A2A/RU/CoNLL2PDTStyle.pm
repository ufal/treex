package Treex::Block::A2A::RU::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CoNLL2PDTStyle';



#------------------------------------------------------------------------------
# Reads the Russian tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $a_root = $self->SUPER::process_zone($zone, 'syntagrus');
    # Adjust the tree structure.
    $self->attach_final_punctuation_to_root($a_root);
#    $self->restructure_coordination($a_root);
#    $self->check_afuns($a_root);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://www.ims.uni-stuttgart.de/projekte/TIGER/TIGERCorpus/annotation/tiger_scheme-syntax.pdf
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $sp_counter = 0;
    foreach my $node (@nodes)
    {
        # The corpus contains the following 46 dependency relation tags:
        # -- AC ADC AG AMS APP AVC CC CD CJ CM CP CVC DA DH DM EP HD JU MNR MO NG NK NMC
        # OA OA2 OC OG OP PAR PD PG PH PM PNC PUNC RC RE ROOT RS SB SBP SP SVP UC VO
        my $deprel = $node->conll_deprel();
        my $parent = $node->parent();
        my $pos = $node->get_iset('pos');
        my $ppos = $parent->get_iset('pos');
        my $afun;
        # Dependency of the main verb on the artificial root node.
        if(!defined($deprel))
        {
            $node->set_conll_deprel('ROOT');
            if($pos eq 'verb')
            {
                $afun = 'Pred';
            }
            else
            {
                $afun = 'ExD';
            }
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in German trees.
# - The first member is the root.
# - Any non-first member is attached to the previous member with afun CoordArg.
#   If prepositional phrases have already been processed and there is
#   coordination of prepositional phrases, the prepositins are tagged AuxP and
#   the CoordArg afun is found at the only child of the preposition.
# - Coordinating conjunction is attached to the previous member with afun Coord.
# - Comma is attached to the previous member with afun AuxX.
# - Shared modifiers are attached to the first member. Private modifiers are
#   attached to the member they modify.
# Note that under this approach:
# - Shared modifiers cannot be distinguished from private modifiers of the
#   first member.
# - Nested coordinations ("apples, oranges and [blackberries or strawberries]")
#   cannot be distinguished from one large coordination.
# Special cases:
# - Coordination lacks any conjunctions or punctuation with the CD deprel tag.
#   Example:
#   `` Spürst du das ? '' , fragt er , `` spürst du den Knüppel ?
#   In this example, the second 'spürst' is attached as a CoordArg to the first
#   'Spürst'. All punctuation is attached to 'fragt', so we don't see the
#   second comma as the potential coordinating node.
#   Possible solutions:
#   Ideally, there'd be a separate function that would reattach punctuation
#   first. Commas before and after nested clauses, including direct speech,
#   would be part of the clause and not of the surrounding main clause. Same
#   for quotation marks around direct speech. And then we would have to
#   find out that there is a comma before the second 'spürst' that can be used
#   as coordinator.
#   In reality we will be less ambitious and develop a robust fallback for
#   coordination without coordinators.
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Collects members, delimiters and modifiers of one coordination. Recursive.
# Leaves the arrays empty if called on a node that is not a coordination
# member.
#------------------------------------------------------------------------------
sub collect_coordination_members
{
    my $self = shift;
    my $croot = shift; # the first node and root of the coordination
    my $members = shift; # reference to array where the members are collected
    my $delimiters = shift; # reference to array where the delimiters are collected
    my $sharedmod = shift; # reference to array where the shared modifiers are collected
    my $privatemod = shift; # reference to array where the private modifiers are collected
    my $debug = shift;
    # Is this the top-level call in the recursion?
    my $toplevel = scalar(@{$members})==0;
    my @children = $croot->children();
    log_info('DEBUG ON '.scalar(@children)) if($debug);
    # No children to search? Nothing to do!
    return if(scalar(@children)==0);
    # AuxP occurs only if prepositional phrases have already been processed.
    # AuxP node cannot be the first member of coordination ($toplevel).
    # However, AuxP can be non-first member. In that case, its only child bears the CoordArg afun.
    if($croot->afun() eq 'AuxP')
    {
        if($toplevel)
        {
            return;
        }
        else
        {
            # We know that there is at least one child (see above) and for AuxP, there should not be more than one child.
            # Make the PrepArg child the member instead of the preposition.
            $croot = $children[0];
            @children = $croot->children();
        }
    }
    my @members0;
    my @delimiters0;
    my @sharedmod0;
    my @privatemod0;
    @members0 = grep {my $x = $_; $x->afun() eq 'CoordArg' || $x->afun() eq 'AuxP' && grep {$_->afun() eq 'CoordArg'} ($x->children())} (@children);
    if(@members0)
    {
        # If $croot is the real root of the whole coordination we must include it in the members, too.
        # However, if we have been called recursively on existing members, these are already present in the list.
        if($toplevel)
        {
            push(@{$members}, $croot);
        }
        push(@{$members}, @members0);
        # All children with the 'Coord' afun are delimiters (coordinating conjunctions).
        # Punctuation children are usually delimiters, too.
        # They should appear between two members, which would normally mean between $croot and its (only) CoordArg.
        # However, the method is recursive and "before $croot" could mean between $croot and the preceding member. Same for the other end.
        # So we take all punctuation children and hope that other punctuation (such as delimiting modifier relative clauses) would be descendant but not child.
        my @delimiters0 = grep {$_->afun() =~ m/^(Coord|AuxX|AuxG)$/} (@children);
        push(@{$delimiters}, @delimiters0);
        # Recursion: If any of the member children (i.e. any members except $croot)
        # have their own CoordArg children, these are also members of the same coordination.
        foreach my $member (@members0)
        {
            $self->collect_coordination_members($member, $members, $delimiters);
        }
        # If this is the top-level call in the recursion, we now have the complete list of coordination members
        # and we can call the method that collects and sorts out coordination modifiers.
        if($toplevel)
        {
            $self->collect_coordination_modifiers($members, $sharedmod, $privatemod);
        }
    }
}



#------------------------------------------------------------------------------
# For a list of coordination members, finds their modifiers and sorts them out
# as shared or private. Modifiers are children whose afuns do not suggest they
# are members (CoordArg) or delimiters (Coord|AuxX|AuxG).
#------------------------------------------------------------------------------
sub collect_coordination_modifiers
{
    my $self = shift;
    my $members = shift; # reference to input array
    my $sharedmod = shift; # reference to output array
    my $privatemod = shift; # reference to output array
    # All children of all members are modifiers (shared or private) provided they are neither members nor delimiters.
    # Any left modifiers of the first member will be considered shared modifiers of the coordination.
    # Any right modifiers of the first member occurring after the second member will be considered shared modifiers, too.
    # Note that the DDT structure does not provide for the distinction between shared modifiers and private modifiers of the first member.
    # Modifiers of the other members are always private.
    my $croot = $members->[0];
    my $ord0 = $croot->ord();
    my $ord1 = $#{$members}>=1 ? $members->[1]->ord() : -1;
    foreach my $member (@{$members})
    {
        my @modifying_children = grep {$_->afun() !~ m/^(CoordArg|Coord|AuxX|AuxG)$/} ($member->children());
        if($member==$croot)
        {
            foreach my $mchild (@modifying_children)
            {
                my $ord = $mchild->ord();
                if($ord<$ord0 || $ord1>=0 && $ord>$ord1)
                {
                    push(@{$sharedmod}, $mchild);
                }
                else
                {
                    # This modifier of the first member occurs between the first and the second member.
                    # Consider it private.
                    push(@{$privatemod}, $mchild);
                }
            }
        }
        else
        {
            push(@{$privatemod}, @modifying_children);
        }
    }
}



1;



=over

=item Treex::Block::A2A::RU::CoNLL2PDTStyle

Converts Syntagrus (Russian Dependency Treebank) trees to the style of
the Prague Dependency Treebank.
Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
