package Treex::Block::Read::Sentences;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has 'skip_empty' => (is => 'ro', isa => 'Bool', default => 0);

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $sentence ( split /\n/, $text ) {
        next if ($sentence eq '' and $self->skip_empty);
        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        $zone->set_sentence($sentence);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Sentences

=head1 SYNOPSIS

 Read::Sentences from='!dir*/file*.txt' skip_empty=1

=head1 DESCRIPTION

Document reader for plain text format, one sentence per line.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the 
L<document|Treex::Core::Document>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames
See L<Treex::Core::Files> for full syntax.

=item skip_empty

If set to 1, ignore empty lines (don't create empty sentences). 

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>
L<Treex::Block::Read::AlignedSentences>
L<Treex::Block::Read::SentencesTSV>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
