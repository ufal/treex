package Treex::Block::Read::SentencesTSV;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has 'langs'  => (is => 'ro', isa => 'Str', required => 1);

has 'skip_empty' => (is => 'ro', isa => 'Bool', default => 0);

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my @langs = split /[, ]/, $self->langs;
    
    my $document = $self->new_document();
    foreach my $sentence ( split /\n/, $text ) {
        next if ($sentence eq '' and $self->skip_empty);
        my @sentences = split /\t/, $sentence;
        log_fatal "Wrong number of sentences/languages per line:\nsentence=$sentence\nlangs=".$self->langs
            if @sentences != @langs;
        
        my $bundle = $document->create_bundle();
        foreach my $lang (@langs){
            if ($lang eq "BUNDLE_ID") {
                $bundle->set_id( shift @sentences);
            } else {
                my ($l, $s) = $lang =~ /-/ ? split(/-/, $lang) : ($lang, $self->selector);
                my $zone = $bundle->create_zone( $l, $s );
                $zone->set_sentence(shift @sentences); 
            }
        }
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::SentencesTSV

=head1 SYNOPSIS

 Read::SentencesTSV from='!dir*/file*.txt' langs=en,cs

 # empty selector by default, can be overriden for both (all) languages
 Read::SentencesTSV from='!dir*/file*.txt' langs=en,cs selector=hello
 
 # or if each language should have different selector
 Read::SentencesTSV from='!dir*/file*.txt' langs=en-hello,cs-bye

 # or if one of the columns contains bundle id
 Read::SentencesTSV from='!dir*/file*.txt' langs=BUNDLE_ID,en-hello,cs-bye

=head1 DESCRIPTION

Document reader for multilingual sentence-aligned plain text format.
One sentence per line, each language separated by a TAB character.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the 
L<document|Treex::Core::Document>.

=head1 ATTRIBUTES

=over

=item langs

space or comma separated list of languages
Each line of each file must contain so many columns.
Language code may be followed by a hyphen and a selector.

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
L<Treex::Block::Read::Sentences>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
