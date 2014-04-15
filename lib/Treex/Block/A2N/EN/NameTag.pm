package Treex::Block::A2N::EN::NameTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2N::NameTag';

has '+model' => ( default => 'data/models/nametag/en/english-conll-140408.ner' );

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::EN::NameTag - English named entity recognizer NameTag

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::A2N::NameTag> which adds the path to the
default model for English.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
