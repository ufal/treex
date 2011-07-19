package Treex::Block::A2T::CS::SetCoapFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $functor;
    my $a_node = $t_node->get_lex_anode();
    my $afun = $a_node ? $a_node->afun : '';

    if ( $t_node->t_lemma eq "a" ) {
        $functor = "CONJ";
    }
    elsif ( $t_node->t_lemma eq "nebo" ) {
        $functor = "DISJ";
    }
    elsif ( $t_node->t_lemma eq "ale" ) {
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

=item Treex::Block::A2T::CS::SetCoapFunctors

Functors (attribute C<functor>) in Czech t-trees have to be assigned in (at
least) two phases. This block corresponds to the first phase, in which only
coordination and apposition functors are filled (which makes it possible to use
the notions of effective parents and effective children in the following
phase).

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
