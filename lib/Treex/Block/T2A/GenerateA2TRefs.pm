package Treex::Block::T2A::GenerateA2TRefs;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_tnode
{
    my $self = shift;
    my $tnode = shift;
    # A t-node refers to zero or one lexical a-node, and to any number of
    # auxiliary a-nodes. We ignore the auxiliaries here.
    # The a-node may lie in a different sentence but it should not happen if
    # the t-node is not generated.
    unless($tnode->is_generated())
    {
        my $anode = $tnode->get_lex_anode();
        if(defined($anode))
        {
            $anode->wild()->{'tnode.rf'} = $tnode->id();
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::GenerateA2TRefs

=item DESCRIPTION

T-nodes have references to a-nodes (lex.rf and aux.rf) but there are no back
references from a-nodes to t-nodes. When exporting a mixture of a- and t-layer
annotations in certain formats, we may have to access t-nodes from their
lexical a-nodes. This block generates such references and stores them as wild
attributes of the a-nodes.

Furthermore, it generates empty a-nodes corresponding to generated t-nodes, in
the form recognized by Write::CoNLLU. The empty nodes can thus be exported as
empty nodes in enhanced UD graphs.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
