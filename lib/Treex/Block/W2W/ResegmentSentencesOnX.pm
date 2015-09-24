package Treex::Block::W2W::ResegmentSentencesOnX;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    my @nodes = $root->get_descendants({'ordered' => 1});
    # Is there a proposal for a new sentence break?
    my $break = any {$_->id() =~ m/^x/} (@nodes);
    return unless($break);
    # The annotator may have introduced new nodes if the last token of the first sentence was stuck to the first token of the second sentence.
    # It is not guaranteed that the ords of the nodes were adjusted accordingly.
    # However, it should have been corrected when reading the file in Treex, so the following is just a sanity check.
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $ord = $nodes[$i]->ord();
        if($ord != $i+1)
        {
            log_warn(join(' ', map {$_->ord()} (@nodes)));
            log_fatal("Ord mismatch");
        }
    }
    # Sort out the nodes of the individual sentences.
    my @s1;
    my @sentences = (\@s1);
    my $current_sentence = \@s1;
    foreach my $node (@nodes)
    {
        if($node->id() =~ m/^x/)
        {
            # This is the first node of a new sentence.
            my @new_sentence;
            push(@sentences, \@new_sentence);
            $current_sentence = \@new_sentence;
        }
        push(@{$current_sentence}, $node);
    }
    # Create bundles for the new sentences.
    my $current_bundle = $zone->get_bundle();
    my $document = $current_bundle->get_document();
    for(my $i = 1; $i<=$#sentences; $i++)
    {
        my $new_bundle = $document->create_bundle({'after' => $current_bundle});
        my $new_zone = $new_bundle->create_zone($self->language(), $self->selector());
        my $new_tree = $new_zone->create_atree();
        # Get the minimal and maximal ords in this sentence.
        my $minord;
        my $maxord;
        foreach my $node (@{$sentences[$i]})
        {
            if(!defined($minord) || $node->ord() < $minord)
            {
                $minord = $node->ord();
            }
            if(!defined($maxord) || $node->ord() > $maxord)
            {
                $maxord = $node->ord();
            }
        }
        # Find nodes whose parents are out of this sentence (most notably the root parent).
        # Reattach them to the root of the new tree.
        foreach my $node (@{$sentences[$i]})
        {
            my $pord = $node->parent()->ord();
            if($pord < $minord || $pord > $maxord)
            {
                $node->set_parent($new_tree);
            }
        }
        # Modify the ords in the new sentence so that they start at 1 again.
        $new_tree->_normalize_node_ordering();
        # Make the new bundle current, just in case we will be creating another bundle, so that we know where to place it.
        $current_bundle = $new_bundle;
    }
    $root->_normalize_node_ordering();
}



1;

=over

=item Treex::Block::W2W::ResegmentSentencesOnX

If there are errors in sentence segmentation, the annotator may edit the trees
in Tred and precede ids of nodes that should start a new sentence with I<x>.
Thus instead of C<a_tree_...> we will have C<xa_tree_...>.
This block will then take care of the rest.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
