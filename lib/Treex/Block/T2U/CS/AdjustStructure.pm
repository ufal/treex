package Treex::Block::T2U::CS::AdjustStructure;
use utf8;
use Moose;
extends 'Treex::Block::T2U::AdjustStructure';

=head1 NAME

Treex::Block::T2U::CS::AdjustStructure - Czech specifics for converting t-layer to u-layer.

=cut

sub is_exclusive {
    my ($self, $tlemma) = @_;
    return $tlemma =~ /^(?:jen(?:om)?|pouze|výhradně)$/
}

sub negation { 'n(?:e|ikoliv?)' }

__PACKAGE__->meta->make_immutable
