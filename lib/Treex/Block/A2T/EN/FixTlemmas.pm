package Treex::Block::A2T::EN::FixTlemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;
    my $lex_a_node = $node->get_lex_anode or return;
    my $old_tlemma = $node->t_lemma;
    my $new_tlemma;
    my @particles;
    my @aux_a_nodes = $node->get_aux_anodes();

    if ( $old_tlemma eq 'not' ) {
        $new_tlemma = '#Neg';
    }
    elsif ( $lex_a_node->tag =~ /^PRP/ ) {
        $new_tlemma = '#PersPron';
    }
    elsif (
        $node->get_attr('a/aux.rf') and    # e.g. "sell out" -> t_lemma sell_out
        @particles = grep { $_->tag eq 'RP' } @aux_a_nodes
        )
    {
        $new_tlemma = $old_tlemma . '_' . ( join '_', map { $_->lemma } @particles );
    }
    else {
        my $full_expression = join '_', map { $_->lemma }
            sort { $a->ord <=> $b->ord } grep { $_->tag !~ /^(,|-|;)/ } ( $lex_a_node, @aux_a_nodes );

        if ( $full_expression =~ /^(as_well_as|as_well)$/ ) {
            $new_tlemma = $1;
        }
    }

    if ($new_tlemma) {
        $node->set_t_lemma($new_tlemma);
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::FixTlemmas

=head1 DESCRIPTION

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, particle is joined with the base verb in the case of phrasal verbs, etc.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
