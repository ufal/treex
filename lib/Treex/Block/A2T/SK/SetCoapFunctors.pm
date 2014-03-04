package Treex::Block::A2T::SK::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $functor;
    my $a_node = $t_node->get_lex_anode();
    my $afun = $a_node ? $a_node->afun : '';

    if ( $t_node->t_lemma =~ /^(a|i|aj|ani)$/ ) {
        $functor = "CONJ";
    }
    elsif ( $t_node->t_lemma =~ /^(alebo|či)$/ ) {
        $functor = "DISJ";
    }
    elsif ( $t_node->t_lemma =~ /^(ale|no)$/ ) {
        $functor = "ADVS";
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


