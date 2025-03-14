package Treex::Block::T2U::LA::ConvertCoreference;
use Moose;
extends 'Treex::Block::T2U::ConvertCoreference';
with 'Treex::Tool::UMR::LA::GrammatemeSetter';

=head1 NAME

Treex::Block::T2U::LA::ConvertCoreference - Latin specifics for converting coreference form the t-layer to u-layer.

=cut

{   my $RELATIVE = '(?:qu[aio]|u(?:bi|nde))(?:cumque)?'
                 . '|qu(?:omodo|isquis|alis|antus)';
    sub relative { $RELATIVE }
}

__PACKAGE__->meta->make_immutable
