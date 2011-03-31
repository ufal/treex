package Treex::Block::Write::Sentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has encoding => (
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. By default utf8.',
);

has join_resegmented => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print the sentences re-segmented'
        . ' by W2A::ResegmentSentences on one line.',
);

sub BUILD {
    my ($self) = @_;
    binmode STDOUT, ':encoding(' . $self->encoding . ')';
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $bundle_id = $zone->get_bundle()->id;
    if ( $self->join_resegmented && $bundle_id =~ /_(\d+)of(\d+)$/ && $1 != $2 ) {
        print $zone->sentence, " ";
    }
    else {
        print $zone->sentence, "\n";
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Write::Sentences

=head1 DESCRIPTION

Document writer for plain text format, one sentence per line.


=head1 ATTRIBUTES

=over

=item encoding

Output encoding. By default utf8.

=item join_resegmented

Print the sentences re-segmented
by C<W2A::ResegmentSentences> on one line.

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
