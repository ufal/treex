package Treex::Block::HamleDT::PL::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Splits certain tokens to syntactic words according to the guidelines of the
# Universal Dependencies. This block should be called after the tree has been
# converted to UD, not before!
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->mark_multiword_tokens($root);
}



#------------------------------------------------------------------------------
# Identifies nodes from the original Polish treebank that are part of a larger
# surface token. Marks them as such (multi-word tokens will be visible in the
# CoNLL-U file).
#------------------------------------------------------------------------------
sub mark_multiword_tokens
{
    my $self = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    # Read the words right-to-left. Agglutinating morphemes from the auxiliary
    # verb "być" attach to the preceding word. There are only the following
    # forms: em, m, eś, ś, śmy, ście.
    for(my $i = $#nodes; $i > 0; $i--)
    {
        if($nodes[$i]->lemma() eq 'być' && $nodes[$i]->form() =~ m/^(em|m|eś|ś|śmy|ście)$/)
        {
            $self->mark_multiword_token($nodes[$i-1]->form().$nodes[$i]->form(), $nodes[$i-1], $nodes[$i]);
        }
    }
}



#------------------------------------------------------------------------------
# Marks a sequence of existing nodes as belonging to one multi-word token.
#------------------------------------------------------------------------------
sub mark_multiword_token
{
    my $self = shift;
    my $fused_form = shift;
    # The nodes that form the group. They should form a contiguous span in the sentence.
    # And they should be sorted by their ords.
    my @nodes = @_;
    return if(scalar(@nodes) < 2);
    my $fsord = $nodes[0]->ord();
    my $feord = $nodes[-1]->ord();
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $nnw = $nodes[$i]->wild();
        ###!!! Later we will want to make these attributes normal (not wild).
        $nnw->{fused_form} = $fused_form;
        $nnw->{fused_start} = $fsord;
        $nnw->{fused_end} = $feord;
        $nnw->{fused} = ($i == 0) ? 'start' : ($i == $#nodes) ? 'end' : 'middle';
    }
}



1;

=over

=item Treex::Block::HamleDT::PL::SplitFusedWords

Splits certain tokens to syntactic words according to the guidelines of the
Universal Dependencies. Some of them have already been split in the original
Polish treebank but at least we have to annotate that they belong to a
multi-word token.

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
