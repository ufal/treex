package Treex::Block::A2T::EN::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $functor = get_coap_functor($tnode) or return 1;
    $tnode->set_functor($functor);

    return 1;
}

sub get_coap_functor {
    my ($t_node) = @_;
    my $lemma = $t_node->t_lemma;
    
    return 'DISJ' if $lemma eq 'or';
    return 'ADVS' if $lemma eq 'but';
    return 'ADVS' if $lemma eq 'yet' && grep { $_->is_member } $t_node->get_children();

    #return 'CONJ' if any { $_ eq $lemma } qw(and as_well_as);
    # There can be also other CONJ lemmas (& plus),
    # so it is better to check the tag for CC (after solving DISJ...).
    my $a_node = $t_node->get_lex_anode() or return;
    return 'CONJ' if $a_node->tag eq 'CC';
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetCoapFunctors

=head1 DESCRIPTION

Functors (attribute C<functor>) in English t-trees
have to be assigned in (at least) two phases. This block
corresponds to the first phase, in which only coordination and apposition functors
are filled (which makes it possible to use the notions of effective parents and effective
children in the following phase).

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2009 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
