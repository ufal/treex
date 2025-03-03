package Treex::Block::T2U::LA::AdjustStructure;
use Moose;
extends 'Treex::Block::T2U::AdjustStructure';

=head1 NAME

Treex::Block::T2U::LA::AdjustStructure - Latin specifics for converting t-layer to u-layer.

=cut

sub is_exclusive {
    my ($self, $tlemma) = @_;
    return $tlemma =~ /^(?:solum|tantum)$/
}

sub negation { '(?:n(?:on|e)|haud)' }

__PACKAGE__->meta->make_immutable
