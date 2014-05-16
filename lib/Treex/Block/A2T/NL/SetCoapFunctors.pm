package Treex::Block::A2T::NL::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $functor;
    my $a_node = $t_node->get_lex_anode();
    my $afun = $a_node ? $a_node->afun : '';

    if ( $t_node->t_lemma eq 'en' ) {
        $functor = 'CONJ';
    }
    elsif ( $t_node->t_lemma eq 'of' ) {
        $functor = 'DISJ';
    }
    elsif ( $t_node->t_lemma eq 'maar' and any { $_->is_member } $t_node->get_children() ) {
        $functor = 'ADVS';
    }
    elsif ( $afun eq 'Coord' ) {
        $functor = 'CONJ';
    }
    elsif ( $afun eq 'Apos' ) {
        $functor = 'APPS';
    }

    if ( defined $functor ) {
        $t_node->set_functor($functor);
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetCoapFunctors

=head1 DESCRIPTION

Set just the coordination and apposition C<functor>s in Dutch t-trees.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
