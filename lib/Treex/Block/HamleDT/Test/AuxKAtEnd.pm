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
    # Node cannot be labeled AuxK if it is not the last node.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxK' && $node != $last_node)
        {
            $self->complain($node);
        }
    }
    # Node cannot be labeled AuxX or AuxG if it is the last node.
    if($last_node->deprel() =~ m/^Aux[GX]$/)
    {
        $self->complain($last_node);
    }
}

# (C) 2012 Jindřich Libovický <jlibovicky@gmail.com>
# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

1;
