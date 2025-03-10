package Treex::Block::T2U::LA::AdjustStructure;
use Moose;
extends 'Treex::Block::T2U::AdjustStructure';

use experimental 'signatures';

=head1 NAME

Treex::Block::T2U::LA::AdjustStructure - Latin specifics for converting t-layer to u-layer.

=cut

override is_exclusive => sub($self, $tlemma) {
    $tlemma =~ /^(?:solum|tantum)$/
};

override negation => sub { '(?:n(?:on|e)|haud)' };

__PACKAGE__->meta->make_immutable
