package Treex::Block::A2T::DeleteChildlessPunctuation;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    if ( $tnode->t_lemma =~ /^(\p{Punct}+|-LRB-|-RRB-|``)$/ && $tnode->t_lemma ne '%' && !$tnode->get_children() ) {

        my @anodes = ( $tnode->get_lex_anode(), $tnode->get_aux_anodes() );
        my ($parent) = $tnode->get_eparents( { or_topological => 1 } );

        if ( @anodes && $parent && !$parent->is_root ) {
            $parent->add_aux_anodes(@anodes);
        }
        

        $tnode->remove();
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::DeleteChildlessPunctuation

=head1 DESCRIPTION

Deletes all punctuation t-nodes with no children. Moves the corresponding lexical a-node to the list of auxiliary
a-nodes of the t-node's parent, if possible.  

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
