package Treex::Block::W2A::EscapeMoses;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Moses;

sub process_atree {
    my ($self, $aroot) = @_;

    Treex::Tool::Moses::escape_anodes($aroot);

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EscapeMoses

=head1 DESCRIPTION

Escape anodes in the way the Moses tokenizer does, using L<Treex::Tool::Moses::escape_anodes()>.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

