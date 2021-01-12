package Treex::Block::T2A::GenerateEmptyNodes;
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
    my $lastanode = $anodes[-1];
    my $major = $lastanode->ord();
    my $minor = 0;
    foreach my $tnode (@tnodes)
    {
        if($tnode->is_generated())
        {
            my $anode = $aroot->create_child();
            $anode->set_deprel('dep:empty');
            $anode->wild()->{'tnode.rf'} = $tnode->id();
            $anode->wild()->{enhanced} = [];
            $minor++;
            $anode->wild()->{enord} = "$major.$minor";
            $anode->shift_after_node($lastanode);
            $lastanode = $anode;
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::GenerateEmptyNodes

=item DESCRIPTION

Generates an empty node (as in enhanced UD graphs, in the form recognized by
Write::CoNLLU) for every generated t-node, and stores in its wild attributes
a reference to the corresponding t-node (in the same fashion as GenerateA2TRefs
stores references from real a-nodes to corresponding t-nodes).

While it may be useful to run T2A::GenerateA2TRefs before the conversion from
Prague to UD (so that the conversion procedure has access to tectogrammatic
annotation), calling this block is better postponed until the basic UD tree is
ready. The empty nodes will participate only in enhanced dependencies, so they
are not needed earlier. But they are represented using fake a-nodes, which
might confuse the conversion functions that operate on the basic (a-)tree.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
