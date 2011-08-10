package Treex::Block::A2A::Transform::SharedModifBelowNearestMember;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

# warning: this module does not use the 'transformer' attribute,
# since the simple functionality is implemented directly in this module

sub process_atree {
    my ( $self, $atree ) = @_;

    foreach my $coap ( grep { $_->is_coap_root } $atree->get_descendants ) {

        my @children_from_right = reverse $coap->get_children( { ordered => 1 } );

        my $nearest_right_member;
        my ($last_member) = grep { $_->is_member } @children_from_right;

        foreach my $child (@children_from_right) {

            if ( $child->is_member ) {
                $nearest_right_member = $child;
            }
            else {
                my $new_parent = $nearest_right_member || $last_member;
                if ( not defined $new_parent ) {
                    log_warn('Shared modifier cannot be rehanged, since no co/ap member was found (incorrect co/ap structure)');
                }
                else {
                    $child->set_parent( $nearest_right_member || $last_member );
                    $self->subscribe($child);
                }
            }
        }
    }
}

1;

=over

=item Treex::Block::A2A::Transform::SharedModifBelowMember

Move shared modifiers below the nearest right member of coordinaton
(or below the last member of coordination, if no member follows after
the shared modifier)

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

