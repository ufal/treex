package Treex::Block::HamleDT::HarmonizePDT;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Prague style trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $tagset = shift;
    my $root = $self->SUPER::process_zone($zone, $tagset);
    my @nodes = $root->get_descendants({ordered => 1});
    # See the comment at sub detect_coordination for why we are doing this even with PDT-style treebanks.
    $self->restructure_coordination($root);
    $self->pdt2hamledt_apposition($root);
    # We used to reattach final punctuation before handling coordination and apposition but that was a mistake.
    # The sentence-final punctuation might serve as coap head, in which case this function must not modify it.
    # The function knows it but it cannot be called before coap annotation has stabilized.
    $self->attach_final_punctuation_to_root($root) unless($#nodes>=0 && $nodes[$#nodes]->afun() eq 'Coord');
    return $root;
}

#------------------------------------------------------------------------------
# Reshapes apposition from the style of PDT to the style of HamleDT. Adapted
# from Martin Popel's block Pdt2HamledtApos.
#------------------------------------------------------------------------------
sub pdt2hamledt_apposition
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        next if($node->afun() ne 'Apos');
        my $old_head = $node;
        my @children = $old_head->get_children({ordered=>1});
        my ($first_ap, @other_ap) = grep {$_->is_member()} (@children);
        if (!$first_ap)
        {
            log_warn('Apposition without members at ' . $old_head->get_address());
            # Something is wrong but we cannot allow the 'Apos' afun in the output.
            if($old_head->form() eq ',')
            {
                $old_head->set_afun('AuxX');
            }
            elsif($old_head->is_punctuation())
            {
                $old_head->set_afun('AuxG');
            }
            elsif(scalar(@children)>0 && $children[0]->afun() ne 'Apos')
            {
                $old_head->set_afun($children[0]->afun());
            }
            else
            {
                $old_head->set_afun('AuxY');
            }
            next;
        }
        # Usually, apposition has exactly two members.
        # However, ExD (and unannotated coordination) can result in more members
        # and the second member can be the whole following sentence (i.e. just one member in the tree).
        # We must be prepared also for such cases. Uncomment the following line to see them.
        #log_warn 'Strange apposition at ' . $old_head->get_address() if @other_ap != 1;
        # Make the first member of apposition the new head.
        $first_ap->set_parent($old_head->get_parent());
        $first_ap->set_is_member(0);
        # Attach other apposition members (hopefully just one) to the new head.
        foreach my $another_ap (@other_ap)
        {
            $another_ap->set_parent($first_ap);
            $another_ap->set_is_member(0);
            # $another_ap could be coordination, preposition or subordinating conjunction, then the afun would have to be set further down.
            $another_ap->set_real_afun('Apposition');
        }
        # Attach the comma (or semicolon or dash or bracket) under the second apposition member.
        if (@other_ap)
        {
            $old_head->set_parent($other_ap[0]);
        }
        else
        {
            $old_head->set_parent($first_ap);
        }
        $old_head->set_afun($old_head->form eq ',' ? 'AuxX' : 'AuxG');
        # Reattach children of the comma, such as a second comma etc.
        my $new_parent = $old_head->parent();
        @children = $old_head->get_children();
        foreach my $child (@children)
        {
            $child->set_parent($new_parent);
        }
        # Reattach possible AuxG (dashes or right brackets) under the last member of apposition.
        my @auxg = grep {!$_->is_member && $_->afun eq 'AuxG'} @children;
        if (@other_ap)
        {
            foreach my $bracket (@auxg)
            {
                $bracket->set_parent($other_ap[-1]);
            }
        }
        # If the whole apposition was a conjunct of some outer coordination, is_member must stay with the head
        if ($old_head->is_member)
        {
            $first_ap->set_is_member(1);
            $old_head->set_is_member(0);
        }
    }
}



#------------------------------------------------------------------------------
# Detects coordination in the shape we expect to find it in PDT and derived
# treebanks. Even though the harmonized shape will be almost identical (the
# input is supposed to adhere to the style that is also used in HamleDT), there
# are slight deviations that we want to polish by decoding and re-encoding the
# coordinations. For example, in PADT the first conjunction serves as the head
# of multi-conjunct coordination, while HamleDT uses the last conjunction. This
# function will also make sure that additional attributes related to
# coordination (such as is_shared_modifier) will be properly set.
#------------------------------------------------------------------------------
sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    $coordination->detect_prague($node);
    # The caller does not know where to apply recursion because it depends on annotation style.
    # Return all conjuncts and shared modifiers for the Prague family of styles.
    # Return orphan conjuncts and all shared and private modifiers for the other styles.
    my @recurse = $coordination->get_conjuncts();
    push(@recurse, $coordination->get_shared_modifiers());
    return @recurse;
}



#------------------------------------------------------------------------------
# This method is called for coordination nodes whose members do not have the
# is_member attribute set (this is an annotation error but it happens).
# The function estimates, based on afuns, which children are members and which
# are shared modifiers.
# Note that it could be used to fix apposition as well but HamleDT does not
# treat apposition as a paratactic structure.
#------------------------------------------------------------------------------
sub identify_conjuncts
{
    my $self = shift;
    my $coap = shift;
    # We should not estimate coap membership if it is already known!
    foreach my $child ($coap->children())
    {
        if($child->is_member())
        {
            log_warn('Trying to estimate CoAp membership of a node that is already marked as member.');
        }
    }
    # Get the list of nodes involved in the structure.
    my @involved = $coap->get_children({'ordered' => 1, 'add_self' => 1});
    # Get the list of potential members and modifiers, i.e. drop delimiters.
    # Note that there may be more than one Coord|Apos node involved if there are nested structures.
    # We simplify the task by assuming (wrongly) that nested structures are always members and never modifiers.
    # Delimiters can have the following afuns:
    # Coord|Apos ... the root of the structure, either conjunction or punctuation
    # AuxY ... other conjunction
    # AuxX ... comma
    # AuxG ... other punctuation
    my @memod = grep {$_->afun() !~ m/^Aux[GXY]$/ && $_!=$coap} (@involved);
    # If there are only two (or fewer) candidates, consider both members.
    if(scalar(@memod)<=2)
    {
        foreach my $m (@memod)
        {
            $m->set_is_member(1);
        }
    }
    else
    {
        # Hypothesis: all members typically have the same afun.
        # Find the most frequent afun among candidates.
        # For the case of ties, remember the first occurrence of each afun.
        # Do not count nested 'Coord' and 'Apos': these are jokers substituting any member afun.
        # Same for 'ExD': these are also considered members (in fact they are children of an ellided member).
        my %count;
        my %first;
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            next if($afun =~ m/^(Coord|Apos|ExD)$/);
            $count{$afun}++;
            $first{$afun} = $m->ord() if(!exists($first{$afun}));
        }
        # Get the winning afun.
        my @afuns = sort
        {
            my $result = $count{$b} <=> $count{$a};
            unless($result)
            {
                $result = $first{$a} <=> $first{$b};
            }
            return $result;
        }
        (keys(%count));
        # Note that there may be no specific winning afun if all candidate afuns were Coord|Apos|ExD.
        my $winner = @afuns ? $afuns[0] : '';
        ###!!! If the winning afun is 'Atr', it is possible that some Atr nodes are members and some are shared modifiers.
        ###!!! In such case we ought to check whether the nodes are delimited by a delimiter.
        ###!!! This has not yet been implemented.
        foreach my $m (@memod)
        {
            my $afun = defined($m->afun()) ? $m->afun() : '';
            if($afun eq $winner || $afun =~ m/^(Coord|Apos|ExD)$/)
            {
                $m->set_is_member(1);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::HarmonizePDT

Common methods needed for conversion of treebanks from the Prague family to HamleDT.
Since the HamleDT annotation style is for most part identical to the style of PDT,
this block merely handles slight deviations of the other Prague and Prague-like treebanks.
It also provides methods for fixing some errors, such as missing conjuncts in coordination.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
