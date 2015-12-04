package Treex::Block::HamleDT::HarmonizePDT;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::Prague;
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
    # An easy bug to fix in afuns. It is rare but it exists.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxX' && $node->form() ne ',' && $node->is_punctuation())
        {
            $node->set_deprel('AuxG');
        }
        # The letter 'x' used instead of the operator of multiplication ('×').
        if($node->deprel() eq 'AuxG' && $node->form() eq 'x' && $node->is_conjunction())
        {
            $node->set_deprel('AuxY');
        }
        # AuxK used for question marks and exclamation marks that terminate phrases but not the whole sentence.
        if($node->deprel() eq 'AuxK' && !$node->parent()->is_root())
        {
            $node->set_deprel($node->form() eq ',' ? 'AuxX' : 'AuxG');
        }
    }
    # Phrase-based implementation of tree transformations (30.11.2015).
    my $builder = new Treex::Tool::PhraseBuilder::Prague
    (
        'prep_is_head'           => 1,
        'cop_is_head'            => 1, ###!!! To tenhle builder vůbec neřeší.
        'coordination_head_rule' => 'last_coordinator',
        'counted_genitives'      => $self->language() ne 'la' ###!!! V tomhle builderu se s genitivy nic nedělá, ne?
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # We used to reattach final punctuation before handling coordination and apposition but that was a mistake.
    # The sentence-final punctuation might serve as coap head, in which case this function must not modify it.
    # The function knows it but it cannot be called before coap annotation has stabilized.
    $self->attach_final_punctuation_to_root($root);
    # is_member undef and is_member 0 are equivalent; however, the latter makes larger XML file.
    foreach my $node (@nodes)
    {
        $node->set_is_member(undef) if(!$node->is_member());
    }
    return $root;
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
