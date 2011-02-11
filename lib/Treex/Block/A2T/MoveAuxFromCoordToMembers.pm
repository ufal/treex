package Treex::Block::A2T::MoveAuxFromCoordToMembers;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

# TODO: storing parameters (block instance variables) as global (class variable) is undue.
# The block can not be used more times (with different parameters) in one scenario.
# But calling get_parameter every time or using Conway's %language_of : ATTR (:get<language>);
# is counter-intuitive and noisy. Waiting for Perl to become OOP language...

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or next;
    next if $a_node->afun !~ /^(Coord|Apos)$/;
    $self->check_coordination($t_node);
    return 1;
}

sub check_coordination {
    my ( $self, $t_coord ) = @_;

    # TODO: can we use get_eff_children() now?
    # Afuns are surely not filled, but is_member should suffice.
    my @t_children = $t_coord->get_children( { ordered => 1 }) or return;
    my @aux_anodes = $t_coord->get_aux_anodes();
    my ( @aux_to_coord, @aux_to_members );

    # get surface position of the first and last child
    my ($first_child_ord, $last_child_ord);
    my @coord_members = grep { $_->is_member } @t_children;
    while (@coord_members and not $coord_members[0]->get_lex_anode ) {
        shift @coord_members;
    }
    while (@coord_members and not $coord_members[$#coord_members]->get_lex_anode ) {
        pop @coord_members;
    }
    if ( @coord_members ) {
        $first_child_ord = $coord_members[0]->get_lex_anode->ord;
        $last_child_ord = $coord_members[$#coord_members]->get_lex_anode->ord;
    }

    # Distinguish two types of aux a-nodes:
    # @aux_to_coord - can be left as a/aux.rf in the coordination (e.g. commas, nodes between the members)
    # @aux_to_members - will be "moved" to members' a/aux.rf (mostly prepositions)
    foreach my $aux (@aux_anodes) {
        my $aux_ord = $aux->ord;
        my $is_between_members = ( @coord_members && $aux_ord > $first_child_ord && $aux_ord < $last_child_ord) ? 1 : 0;
        if ( $self->can_be_aux_to_coord($aux) or $is_between_members ) {
            push @aux_to_coord, $aux;
        }
        else {
            push @aux_to_members, $aux;
        }
    }
  
    # put prepositions as aux to children which are members of the coordination
    foreach my $member ( grep { $_->is_member } @t_children ) {
        $member->add_aux_anodes(@aux_to_members);
    }

    # put the rest (non-preps = mostly commas) to the coordination
    $t_coord->set_aux_anodes(@aux_to_coord);
    return;
}

# This method can be overriden by language specific
# e.g. return $a_node->tag !~ /^(IN|TO)$/
# or if you don't want to have special t-nodes for rhematizers...
sub can_be_aux_to_coord {
    my ( $self, $a_node ) = @_;
    return $a_node->form =~ /^[,;.()]$/;
}

1;

=over

=item Treex::Block::A2T::MoveAuxFromCoordToMembers

Coordination t-nodes should normaly have no aux a-nodes (C<a/aux.rf>) or only commas.
However when building t-layer e.g. from the phrase "in Prague and London"
using the C<SxxA_to_SxxT::Build_ttree> block,
the a-node I<in> is marked as aux with the coordination (t-node I<and>).
This block removes the reference to I<in> from the coordination head
and adds two such references to the members of the coordination
(i.e. t-nodes I<Prague> and I<London>).

For all t-nodes, the attribute C<is_member> must be correctly filled
before applying this block (see L<SxxA_to_SxxT::Fill_is_member>).

PARAMETERS: LANGUAGE

METHODS TO OVERRIDE: $block->can_be_aux_to_coord($a_node)
Can this auxiliary node be in C<a/aux.rf> of a coordination t-node?
Otherwise it is "copied/moved" to C<a/aux.rf> of members of the coodrination.
In this default implementation only punctuation (mainly commas) can be aux to coord.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
