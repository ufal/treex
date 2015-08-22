package Treex::Block::Write::Sentences;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.txt' );

has join_resegmented => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print the sentences re-segmented'
        . ' by W2A::ResegmentSentences on one line.',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $bundle_id = $zone->get_bundle()->id;
    if ( $self->join_resegmented && $bundle_id =~ /_(\d+)of(\d+)$/ && $1 != $2 ) {
        print { $self->_file_handle } $zone->sentence, " ";
    }
    else {
        print { $self->_file_handle } $zone->sentence, "\n";
    }
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::Sentences

=head1 DESCRIPTION

Document writer for plain text format, one sentence
(L<bundle|Treex::Core::Bundle>) per line.


=head1 ATTRIBUTES

=over

=item encoding

Output encoding. C<utf8> by default.

=item join_resegmented

Print the sentences re-segmented
by L<Treex::Block::W2A::ResegmentSentences> on one line.

=item to

The name of the output file, STDOUT by default.

=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
