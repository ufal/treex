package Treex::Block::A2T::GRC::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# TODO: fill correct functors in the table.
# Possible coordination functors are ADVS CONFR CONJ CONTRA CSQ DISJ GRAD REAS OPER
# see http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/t-layer/html/ch07s12s01.html

my %FUNCTOR_FOR_COORD_LEMMA = (
    καί1   => 'CONJ', # Coord=262
    δέ1    => 'CONJ', # Coord= 74
    ἀλλά1  => 'CONJ', # Coord= 16
    τε1    => 'CONJ', # Coord= 16
    ἤ1     => 'CONJ', # Coord=  4
    μήτε1  => 'CONJ', # Coord=  2
    ξομμα1 => 'CONJ', # Coord=  4  (if afun=Apos then functor=APPS is assigned disregarding this table)
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if (my $functor = $self->guess_functor($t_node)){
        $t_node->set_functor($functor);
    }
    return;
}

sub guess_functor {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    my $afun = $a_node ? $a_node->afun : '';
    return 'APPS' if $afun eq 'Apos';
    return $FUNCTOR_FOR_COORD_LEMMA{$t_node->t_lemma} || 'CONJ' if $afun eq 'Coord';
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::GRC::RehangUnaryCoordConj

=head1 DESCRIPTION 

Functors (attribute C<functor>) in t-trees have to be assigned in (at
least) two phases. This block corresponds to the first phase, in which only
coordination and apposition functors are filled (which makes it possible to use
the notions of effective parents and effective children in the following
phase).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
