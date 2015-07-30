package Treex::Block::T2T::EN2CS::CutVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::CutVariants';

sub BUILD {
    log_warn 'This block is deprecated, use T2T::CutVariants instead';
    return;
}

1;

=pod

This block is deprecated, use T2T::CutVariants instead
