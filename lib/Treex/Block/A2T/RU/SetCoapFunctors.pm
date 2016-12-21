package Treex::Block::A2T::RU::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $functor;
    my $a_node = $t_node->get_lex_anode();
    my $afun = $a_node ? $a_node->afun : '';

    if ( $t_node->t_lemma eq "и" || $t_node->t_lemma eq "И" ) {
        $functor = "CONJ";
    }
    elsif ( $t_node->t_lemma eq "ИЛИ" ) {
        $functor = "DISJ";
    }
    elsif ( $t_node->t_lemma eq "но" || $t_node->t_lemma eq "НО" ) {
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

=over

=item Treex::Block::A2T::RU::SetCoapFunctors

Functors (attribute C<functor>) in Czech t-trees have to be assigned in (at
least) two phases. This block corresponds to the first phase, in which only
coordination and apposition functors are filled (which makes it possible to use
the notions of effective parents and effective children in the following
phase).

=back

=cut

# Copyright 2016, Michal Novák

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
