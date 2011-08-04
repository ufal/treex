package Treex::Block::A2T::MarkParentheses;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes();
    if (grep { $_->form =~ /(\(|-LRB-)/ }
        @aux_a_nodes
        and grep { $_->form =~ /(\)|-RRB-)/ } @aux_a_nodes
        )
    {
        $t_node->set_is_parenthesis(1);
    }
    return 1;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::MarkParentheses

=head1 DESCRIPTION

Fills C<is_parenthesis> attribute of parenthetized t-nodes
(nodes having both left and right parentheses in aux a-nodes).

=head1 AUTHOR

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
