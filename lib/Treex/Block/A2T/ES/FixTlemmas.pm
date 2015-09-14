package Treex::Block::A2T::ES::FixTlemmas;
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

    if ( $old_tlemma eq 'no' ) {
        $new_tlemma = '#Neg';
    }
    elsif ( ($node->gram_sempos || "") =~ /n\.pron\.def\.pers/ ) {
        $new_tlemma = '#PersPron';
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

Treex::Block::A2T::ES::FixTlemmas

=head1 DESCRIPTION

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, etc.

=head1 AUTHOR

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
