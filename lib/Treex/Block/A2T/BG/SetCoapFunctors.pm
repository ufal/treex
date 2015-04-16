package Treex::Block::A2T::BG::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetCoapFunctors';

my %LEMMA_TO_FUNCTOR = (
    и => 'CONJ',
    '-' => 'APPS',    
    или => 'DISJ',
    но => 'ADVS',
);

sub get_coap_functor {
    my ($self, $t_node) = @_;
    my $lemma = $t_node->t_lemma;
    return $LEMMA_TO_FUNCTOR{$lemma};
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::BG::SetCoapFunctors

=head1 DESCRIPTION

Functors (attribute C<functor>) in t-trees
have to be assigned in (at least) two phases. This block
corresponds to the first phase, in which only coordination and apposition functors
are filled (which makes it possible to use the notions of effective parents and effective
children in the following phase).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
