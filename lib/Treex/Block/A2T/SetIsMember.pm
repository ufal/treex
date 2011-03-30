package Treex::Block::A2T::SetIsMember;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

# TODO: storing parameters (block instance variables) as global (class variable) is undue.
# The block can not be used more times (with different parameters) in one scenario.
# But calling get_parameter every time or using Conway's %language_of : ATTR (:get<language>);
# is counter-intuitive and noisy. Waiting for Perl to become OOP language...

sub process_tnode {
    my ( $self, $t_node ) = @_;
    if ( is_some_anode_member($t_node) ) {
        $t_node->set_is_member(1);
    }
    return 1;
}

sub is_some_anode_member {
    my ($t_node) = @_;
    return any { $_->is_member } $t_node->get_anodes();
}

1;

=over

=item Treex::Block::A2T::SetIsMember

Coordination members on the t-layer should have the attribute C<is_member = 1>.
This attribute is filled according to the same attribute on the a-layer.

PARAMETERS: LANGUAGE

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
