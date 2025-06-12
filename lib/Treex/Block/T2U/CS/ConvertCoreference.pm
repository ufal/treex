package Treex::Block::T2U::CS::ConvertCoreference;
use utf8;
use Moose;
extends 'Treex::Block::T2U::ConvertCoreference';
with 'Treex::Tool::UMR::CS::GrammatemeSetter';

use experimental qw{ signatures };

=head1 NAME

Treex::Block::T2U::CS::ConvertCoreference - Czech specifics for converting coreference form the t-layer to u-layer.

=cut

{   my $RELATIVE = '(?:který|jenž|jaký|co|kd[ye]|odkud|kudy|kam)';
    sub relative { $RELATIVE }
}

{   my %PRONOUN;
    @PRONOUN{qw{ co což jenž kdo kdož který nač oč on onen tadyhleten
                 tamhleten tamten ten tenhle tenhleten tento tohleto tuhleten
    }} = ();
    sub can_become_entity($self, $tlemma) { exists $PRONOUN{$tlemma} }
}

__PACKAGE__->meta->make_immutable
