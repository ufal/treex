package Treex::Block::A2T::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if ( !$self->is_relative_word($t_node) );

    # get_clause_ehead (effective head of a clause) is needed for coordinated relative clauses, e.g.
    # "a man who(parent=and, eparents={sleeps,eats}) sleeps and eats"
    my $t_relclause_head = $t_node->get_clause_ehead();

    # Antecedent is the parent of relative clause head.
    # (In other words, the relative clause modifies the antecedent.)
    my ($t_antec) = $t_relclause_head->get_eparents( { or_topological => 1 } );
    return if !$t_antec || $t_antec->is_root();
    log_info('T-ANTEC: ' . $t_antec->id . ' ' . $t_antec->t_lemma . ' / ' . $t_node->t_lemma );

    if ( $self->is_allowed_antecedent($t_antec) ) {
        $t_node->set_deref_attr( 'coref_gram.rf', [$t_antec] );
    }
}

sub is_relative_word {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    return ( $a_node and $a_node->match_iset( 'prontype' => '~(rel|int)' ) );
}

sub is_allowed_antecedent {
    my ( $self, $t_antec ) = @_;
    my $a_antec = $t_antec->get_lex_anode();
    return ( $a_antec and ( $a_antec->is_noun or $a_antec->match_iset( 'synpos' => 'subst' ) ) );
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::MarkRelClauseCoref

=head1 DESCRIPTION

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected
and stored into the C<coref_gram.rf> attribute.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
