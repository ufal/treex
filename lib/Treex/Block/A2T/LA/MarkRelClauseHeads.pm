package Treex::Block::A2T::LA::MarkRelClauseHeads;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ( any {$_->get_attr('a/lex.rf') and $_->get_lex_anode->lemma eq "qui"} $t_node->get_children () ) {
       $t_node->set_is_relclause_head(1);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::LA::MarkRelClauseHeads - finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Zdenek Zabokrtsky and Marco Passarotti

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
