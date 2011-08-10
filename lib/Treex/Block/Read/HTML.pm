package Treex::Block::Read::HTML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

use HTML::FormatText;

sub next_document {
    my ($self) = @_;
    my $html = $self->next_document_text();
    return if !defined $html;
    my $text = HTML::FormatText->format_string($html);

    my $document = $self->new_document();
    my $zone = $document->create_zone( $self->language, $self->selector );
    $zone->set_text($text);
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::HTML

=head1 DESCRIPTION

Document reader for HTML format.
The text is stored to the L<document|Treex::Core::Document>'s attribute C<text>.

=head1 TODO

Instead of the current implementation via L<HTML::FormatText> which tries
to preserve some whitespace formatting, we should use
L<HTML::Parser> or L<HTML::TokeParser> and leave just the text,
but mark the paragraph/sentence boundaries that can be detected from HTML tags.

In future, we can store the original HTML markup in the Treex document,
project it e.g. to the translated sentences (via word alignment) and
and insert it back in C<Write::HTML>.

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

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
