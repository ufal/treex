package Treex::Block::A2N::DE::NameTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2N::NameTag';

has '+model' => ( default => 'data/models/nametag/de/german-germeval2014-161223.ner' );

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::DE::NameTag - German named entity recognizer NameTag

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::A2N::NameTag> which adds the path to the
default model for German and filling "raw" lemmas into the C<normalized_name>.

=head1 SEE ALSO

L<Treex::Block::A2N::NameTag>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Michal Novák <mnovakl@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014, 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
