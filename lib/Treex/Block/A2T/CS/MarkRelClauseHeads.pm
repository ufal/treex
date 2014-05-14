package Treex::Block::A2T::CS::MarkRelClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkRelClauseHeads';

override 'is_relative_pronoun' => sub {
    my ($self, $t_node) = @_;
    my $a_node = $t_node->get_lex_anode() or return 0;
    return $a_node->tag =~ /^.[149EJK\?]/;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MarkRelClauseHeads

=head1 DESCRIPTION

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

The Czech implementation uses PDT tags to find relative/interrogative pronouns.

TODO: Switching to Interset will render this override obsolete.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
