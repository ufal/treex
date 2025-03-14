package Treex::Block::T2U::CS::ConvertCoreference;
use utf8;
use Moose;
extends 'Treex::Block::T2U::ConvertCoreference';
with 'Treex::Tool::UMR::CS::GrammatemeSetter';

=head1 NAME

Treex::Block::T2U::CS::ConvertCoreference - Czech specifics for converting coreference form the t-layer to u-layer.

=cut

{   my $RELATIVE = '(?:který|jenž|jaký|co|kd[ye]|odkud|kudy|kam)';
    sub relative { $RELATIVE }
}

__PACKAGE__->meta->make_immutable
