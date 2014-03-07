package Treex::Tool::Tagger::Service;

use Moose;
use namespace::autoclean;
extends 'Treex::Core::Service';
with 'Treex::Tool::Tagger::Role';

has '+module' => ( default => 'tagger' );

sub tag_sentence {
    my ( $self, $tokens_rf ) = @_;

    return @{$self->run($tokens_rf)};
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Tool::Tagger::Service - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Tool::Tagger::Service;
   blah blah blah

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
