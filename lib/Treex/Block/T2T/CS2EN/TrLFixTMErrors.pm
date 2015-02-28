package Treex::Block::T2T::CS2EN::TrLFixTMErrors;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $t_node ) = @_;

    # mít -> #PersPron (because of Czech pro-drop pronouns, the English pronoun aligns with the Czech verb :-( ) 
    if ( $t_node->t_lemma eq '#PersPron' and $t_node->src_tnode->t_lemma eq 'mít' ) {
        $t_node->set_t_lemma('have');
        $t_node->set_attr( 'mlayer_pos', 'V' );
        $t_node->set_t_lemma_origin('rule-TrLFixTMErrors');
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2EN::TrLFixTMErrors

=head1 DESCRIPTION

Fix blatant TM errors due to misalignment.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

