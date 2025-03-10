package Treex::Block::T2U::CS::AdjustStructure;
use utf8;
use Moose;
extends 'Treex::Block::T2U::AdjustStructure';

use experimental 'signatures';

=head1 NAME

Treex::Block::T2U::CS::AdjustStructure - Czech specifics for converting t-layer to u-layer.

=cut

override is_exclusive => sub($self, $tlemma) {
    $tlemma =~ /^(?:jen(?:om)?|pouze|výhradně)$/
};

override negation => sub { 'n(?:e|ikoliv?)' };

__PACKAGE__->meta->make_immutable
