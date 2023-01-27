package Treex::Block::T2A::CopyFunctorsToMisc;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    return if(!exists($anode->wild()->{'tnode.rf'}));
    my $tnode = $anode->get_document()->get_node_by_id($anode->wild()->{'tnode.rf'});
    my $functor = $tnode->functor();
    return if(!defined($functor));
    # We need the a-parent of the a-node. But preferably the one that corresponds to the t-parent of the t-node.
    ###!!! At present we simply take all enhanced parents of the a-node.
    my @eparents = $anode->get_enhanced_parents();
    foreach my $eparent (@eparents)
    {
        $anode->add_functor_relation($eparent->get_conllu_id(), $functor);
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CopyFunctorsToMisc

=item DESCRIPTION

If an a-node has a counterpart in a t-tree, copies its functor from the t-node
to the MISC attribute of the a-node. This block uses the back-references from
the a-tree to the t-tree that we create in T2A::GenerateA2TRefs and in T2A::
GenerateEmptyNodes. We thus no longer consider the get_lex_anode() method of
a t-node. (That method does not know about the empty nodes in Enhanced UD,
so it would not work well for generated t-nodes.) This block should thus be
called after those two blocks.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2023 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
