package Treex::Block::Read::CzengPlaintextReader;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';


enum 'DataVersion' => [ '0.9', '1.0' ];

has '+language' => ( required => 0 );

has [qw(lang1 lang2)] => (
    isa      => 'Treex::Type::LangCode',
    is       => 'ro',
    required => 1,
);

has [qw(selector1 selector2)] => (
    isa     => 'Treex::Type::Selector',
    is      => 'ro',
    default => '',
);

has 'format' => (
    isa     => 'DataVersion',
    is      => 'ro',
    default => '1.0',
);

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $document = $self->new_document();

    LINE:
    foreach my $line ( split /\n/, $text ) {
        my @parts = split /\t/, $line;
        my ( $sentid, $align_score, $sent1, $sent2 );
        if ( $self->format eq "1.0" ) {
            ( $sentid, $align_score, $sent1, $sent2 ) = @parts;
        } elsif ( $self->format eq "0.9" ) {
            ( $sentid, $sent1, $sent2 ) = @parts;
            $align_score = 1;
        }

        my $bundle = $document->create_bundle();
        $bundle->set_attr( 'czeng/id',                   $sentid );
        $bundle->set_attr( 'czeng/align_score',          $align_score );
        $bundle->create_zone( $self->lang1, $self->selector1 )->set_sentence($sent1);
        $bundle->create_zone( $self->lang2, $self->selector2 )->set_sentence($sent2);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CzengPlaintextReader

=head1 DESCRIPTION

Document reader for CzEng plain text format:
one sentence per line, tab separated
sentence_id, align_score,
sentence_in_language1, sentence_in_language2.

E.g.

  ted1.txt.seg-1  1.433   A ono je.   And it is.
  ted1.txt.seg-1  -0.3    A přitom nám to dnes připadá normální.  And yet, it feels natural to us now.

=head1 ATTRIBUTES

=over

=item lang1, lang2

language codes of the two languages (in columns 4 and 5)

=item selector1, selector2

optional selectors for the two languages (in columns 4 and 5)


=item from

space or comma separated list of filenames

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

=head1 AUTHOR

Martin Majlis

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
