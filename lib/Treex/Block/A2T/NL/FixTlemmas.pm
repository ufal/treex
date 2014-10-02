package Treex::Block::A2T::NL::FixTlemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;
    my $lex_a_node = $node->get_lex_anode or return;
    my $old_tlemma = $node->t_lemma;
    my $new_tlemma = $old_tlemma;
    my @particles;
    my @aux_a_nodes = $node->get_aux_anodes();

    # negation particle
    if ( $old_tlemma eq 'niet' ) {
        $new_tlemma = '#Neg';
    }
    # personal (and possessive) pronouns
    elsif ( $lex_a_node->match_iset( 'prontype' => 'prs' ) ) {
        $new_tlemma = '#PersPron';
    }
    else {
        # separable verbal prefixes
        if ( @particles = grep { $_->afun eq 'AuxV' and ($_->is_preposition or $_->is_adverb) } @aux_a_nodes ) {
            $new_tlemma = ( join '', map { $_->lemma } @particles ) . $new_tlemma;
        }
        # reflexiva tantum
        if ( @particles = grep { $_->afun eq 'AuxT'} @aux_a_nodes ){
            $new_tlemma = join('_', map { $_->lemma } @particles ) . '_' . $new_tlemma;
        }
    }

    if ($new_tlemma ne $old_tlemma) {
        $node->set_t_lemma($new_tlemma);
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::NL::FixTlemmas

=head1 DESCRIPTION

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, particle is joined with the base verb in the case of separable prefixes, etc.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
