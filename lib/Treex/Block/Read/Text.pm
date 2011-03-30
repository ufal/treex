package Treex::Block::Read::Text;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    my $zone = $document->create_zone( $self->language, $self->selector );
    $zone->set_text( $text );
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Text

=head1 DESCRIPTION

Document reader for plain text format.
The text is stored to the document's attribute C<text>,
if you want to load a text in "on sentence per line" format to bundles,
use L<Treex::Block::Read::Sentences>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
