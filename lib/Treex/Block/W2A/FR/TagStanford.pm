package Treex::Block::W2A::FR::TagStanford;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TagStanford';

has '+model' => ( default => 'data/models/tagger/stanford/french.tagger' );

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::FR::TagStanford

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::W2A::TagStanford> which adds the path to the
default model for French.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
