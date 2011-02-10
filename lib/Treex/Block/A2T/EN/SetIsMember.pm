package Treex::Block::A2T::EN::SetIsMember;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );


use List::Util qw(first);

# There is a generic block that copies is_member from a-layer to t-layer.
# This is just a wrapper/inherited class for backward compatibility with old scenarios.
use base qw(SxxA_to_SxxT::Fill_is_member);

sub BUILD {
    my ($self) = @_;
    $self->set_parameter( 'LANGUAGE', 'English' );
}

1;

=over

=item Treex::Block::A2T::EN::SetIsMember

Coordination members in SEnglishT trees are marked by value 1 in the C<is_member> attribute.
Their detection is based on the same attribute in SEnglishA trees.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
