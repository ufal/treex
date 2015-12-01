package Treex::Block::HamleDT::Test::AuxKUnderRoot;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# Tests whether AuxK is attached directly to the root node.

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'AuxK')
    {
        my $parent = $node->parent();
        if(defined($parent) && $parent->is_root())
        {
            $self->praise($node);
        }
        else
        {
            $self->complain($node);
        }
    }
}

# (C) 2012 Jindřich Libovický <jlibovicky@gmail.com>
# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

1;
