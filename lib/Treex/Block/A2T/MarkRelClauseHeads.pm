package Treex::Block::A2T::MarkRelClauseHeads;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if ( $self->is_relclause_head($tnode) ) {
        $tnode->set_is_relclause_head(1);
    }

    return 1;
}

sub is_relclause_head {
    my ( $self, $t_node ) = @_;
    return 0 if !$t_node->is_clause_head;

    # Usually wh-pronouns are children of the verb, but sometimes...
    # "licenses, the validity(parent=expire) of which(tparent=validity) will expire"
    return any { $self->is_relative_pronoun($_) } $t_node->get_clause_descendants();
}

sub is_relative_pronoun {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return 0;
    return $a_node->match_iset( 'prontype' => '(rel|int)' );
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MarkRelClauseHeads

=head1 DESCRIPTION

Finds relative clauses and mark their heads using the C<is_relclause_head> attribute.

The default implementation searches for relative/interrogative pronouns within the clause
using Interset.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
