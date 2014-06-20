package Treex::Block::A2T::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if (any {$_->is_member} $tnode->get_children()) {
        if (my $functor = $self->get_coap_functor($tnode)){
            $tnode->set_functor($functor);
        } else {
            foreach my $child ($tnode->get_children()){
                $child->set_is_member(0);
            }
        }
    }
    return;
}

sub get_coap_functor {
    my ($self, $t_node) = @_;
    my $lemma = $t_node->t_lemma;
    
    #return 'DISJ' if $lemma eq 'ou';
    #return 'ADVS' if $lemma =~ /^(mas|porém|senão)$/;
    
    return 'CONJ';
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetCoapFunctors

=head1 DESCRIPTION

Functors (attribute C<functor>) in t-trees
have to be assigned in (at least) two phases. This block
corresponds to the first phase, in which only coordination and apposition functors
are filled (which makes it possible to use the notions of effective parents and effective
children in the following phase).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
