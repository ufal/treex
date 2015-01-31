package Treex::Block::T2A::ES::DeleteSuperfluousAuxCP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::DeleteSuperfluousAuxCP';

override distance_limit_for => sub {
    my ($self, $auxCP_anode, $coap_tnode) = @_;
    return 0 if $coap_tnode->t_lemma eq 'ni';
    return $self->base_distance_limit;
};

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::ES::DeleteSuperfluousAuxCP

=head1 DESCRIPTION

Removing superfluous prepositions or conjunctions in coordinations. 

This is just a Spanish-specific setting for L<Treex::Block::T2A::DeleteSuperfluousAuxCP>.
It seems that conjunction "ni" requires repeated all prepositions.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
