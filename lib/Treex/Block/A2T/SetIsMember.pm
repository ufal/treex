package SxxA_to_SxxT::Fill_is_member;

use utf8;
use 5.008;
use strict;
use warnings;
use Report;
use List::MoreUtils qw( any all );

use base qw(TectoMT::Block);

# TODO: storing parameters (block instance variables) as global (class variable) is undue.
# The block can not be used more times (with different parameters) in one scenario.
# But calling get_parameter every time or using Conway's %language_of : ATTR (:get<language>);
# is counter-intuitive and noisy. Waiting for Perl to become OOP language...

sub START {
    my ($self) = @_;
    my $LANGUAGE = $self->get_parameter('LANGUAGE') or
        Report::fatal('Parameter LANGUAGE must be specified!');
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $LANGUAGE = $self->get_parameter('LANGUAGE');
    my $t_root = $bundle->get_generic_tree("S${LANGUAGE}T");
    foreach my $t_node ( $t_root->get_descendants() ) {
        if ( is_some_anode_member($t_node)) {
            $t_node->set_attr( 'is_member', 1 );
        }
    }
    return;
}

sub is_some_anode_member {
    my ($t_node) = @_;
    return any { $_->get_attr('is_member') } $t_node->get_anodes();
}

1;

=over

=item SxxA_to_SxxT::Fill_is_member

Coordination members on the t-layer should have the attribute C<is_member = 1>.
This attribute is filled according to the same attribute on the a-layer.

PARAMETERS: LANGUAGE

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
