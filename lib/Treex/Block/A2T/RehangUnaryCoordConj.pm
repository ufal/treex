package Treex::Block::A2T::RehangUnaryCoordConj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $a_lex_node = $t_node->get_lex_anode;
    if ( $a_lex_node && $a_lex_node->afun eq 'Coord' && $t_node->get_children == 1 ) {
        my ($t_child) = $t_node->get_children;
        $t_child->set_parent( $t_node->get_parent );
        $t_node->set_parent($t_child);
        $t_child->set_is_member(undef);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::RehangUnaryCoordConj

=head1 DESCRIPTION 

'Coordination conjunctions' (afun=Coord) with only one child
(such as 'však' in Czech or "But" starting an English sentence)
are moved below their children, to be treated as PREC atomic nodes.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
