package Treex::Block::A2T::LA::MarkClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ( any { $_->tag =~ /^3/ } $t_node->get_anodes() ) {
        $t_node->set_is_clause_head(1);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::MarkClauseHeads - mark finite clause heads based on m/tag

=head1 DESCRIPTION 

T-nodes representing the heads of finite verb clauses are marked
by the value 1 in the C<is_clause_head> attribute
if the correspondind lexical a-node's tag starts with "3".

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
