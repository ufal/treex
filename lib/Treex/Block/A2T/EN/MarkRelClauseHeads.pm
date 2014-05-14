package Treex::Block::A2T::EN::MarkRelClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkRelClauseHeads';

override 'is_relative_pronoun' => sub {
    my ($self, $t_node) = @_;
    my $a_node = $t_node->get_lex_anode() or return 0;
    return $a_node->tag =~ /W/;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MarkRelClauseHeads

=head1 DESCRIPTION

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

The English implementation looks for relative/interrogative pronouns within the clause
(their Penn Treebank tag starts with 'W').

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
