package Treex::Block::Test::BaseTester;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub _subscription {
    my ($self) = @_;
    ref($self) =~ /Treex::Block::(.+)/;
    return $1;
}

sub report {
    my ( $self, $node, $message ) = @_;
    print $self->_subscription,
        "\t", $node->get_address,
        ( $message ? "\t$message" : '' ),
        $message, "\n";
}

1;

=over

=item Treex::Block::Test::BaseTester

Common predecessor for testing blocks.
Added method: $block->report($node,$message?)
which prints block's subscription (shortened name), node address,
and optionally an additional message.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

