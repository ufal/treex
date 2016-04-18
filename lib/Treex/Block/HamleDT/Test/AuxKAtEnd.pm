package Treex::Block::HamleDT::Test::AuxKAtEnd;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# Checks whether the sentence-final punctuation is labeled AuxK.

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $last_node = $nodes[-1];
    # Some treebanks contain empty sentences. It is not the primary focus of this test but we have to check it anyway,
    # so why not report it.
    if(!defined($last_node))
    {
        $self->complain($root);
        return;
    }
    # Node cannot be labeled AuxK if it is not the last node.
    # Exception: multiple punctuation symbols at the end of the sentence, such as period + quotation mark, or three dots.
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        if($nodes[$i]->deprel() eq 'AuxK' && $nodes[$i] != $last_node)
        {
            # Do not complain if all subsequent nodes are punctuation.
            for(my $j = $i+1; $j<=$#nodes; $j++)
            {
                if(!defined($nodes[$j]->deprel()) || $nodes[$j]->deprel() !~ m/^Aux[GKX]$/)
                {
                    $self->complain($nodes[$i]);
                    last;
                }
            }
        }
    }
    # Node cannot be labeled AuxX or AuxG if it is the last node.
    # Exception: quotation marks and brackets.
    if($last_node->deprel() =~ m/^Aux[GX]$/ && $last_node->form() !~ m/["”“'’‘\)\]\}]/)
    {
        $self->complain($last_node);
    }
}

# Copyright © 2012 Jindřich Libovický <jlibovicky@gmail.com>
# Copyright © 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

1;
