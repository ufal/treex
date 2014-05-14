package Treex::Block::A2T::MarkClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    $tnode->set_is_clause_head( $self->is_clause_head($tnode) );
    return 1;
}

sub is_clause_head {
    my ( $self, $t_node ) = @_;

    return 0 if ( !$t_node->get_lex_anode );
    return 1 if grep {
        $_->match_iset( 'verbform' => 'fin' )
            or $_->match_iset( 'verbform' => 'part', 'voice' => 'act' )
    } $t_node->get_anodes;
    
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::MarkClauseHeads

=head1 DESCRIPTION

T-nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute.

The default implementation checks for finite verb forms or active participles
among the aux/lex a-nodes (via Interset).

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

