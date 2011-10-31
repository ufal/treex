package Treex::Block::Read::HaliBreaking;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

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

has [qw(id_regex_indicating_doc_break)] => (
    isa      => 'Str',
    is       => 'ro',
    required => 0,
);

sub next_document {
    my ($self) = @_;
    if (!defined $self->{"linecache"} || 0 == scalar(@{$self->{"linecache"}})) {
      my $text = $self->next_document_text();
      return if !defined $text;
      $self->{"linecache"} = [ split /\n/, $text ];
    }
    my $document = $self->new_document();
    my $lastid = undef;

    LINE:
    my $line;
    while ($line = shift @{$self->{"linecache"}}) {
        my ( $sentnum, $blocknum, $sentid, $origfile, $align_score,
             $sent1, $sent2 ) = split /\t/, $line;
        my $regex = $self->id_regex_indicating_doc_break;
        if (defined $regex && $sentid =~ /$regex/o) {
            my $thisid = $1;
            print STDERR "this $thisid, last $lastid\n";
            if (defined $lastid && $thisid ne $lastid) {
                # this sentence starts a new document, emit the previous one
                unshift @{$self->{"linecache"}}, $line;
                return $document;
            }
            $lastid = $thisid;
        }

        # extend the current document
        my $bundle = $document->create_bundle();
        $bundle->set_attr( 'czeng/id',          $sentid );
        $bundle->set_attr( 'czeng/origfile',    $origfile );
        $bundle->set_attr( 'czeng/align_score', $align_score );
        $bundle->create_zone( $self->lang1, $self->selector1 )->set_sentence($sent1);
        $bundle->create_zone( $self->lang2, $self->selector2 )->set_sentence($sent2);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::HaliBreaking

=head1 DESCRIPTION

Document reader for Hunalign plain text format:
one sentence per line, tab separated
sentence_number, block_number, sentence_id, orig_file, align_score,
sentence_in_language1, sentence_in_language2.

E.g.
  
  1 1   ted1	ted1.txt.seg-1	1.433   A ono je.	And it is.
  2 1   ted2	ted1.txt.seg-1	-0.3    A přitom nám to dnes připadá normální.	And yet, it feels natural to us now.

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

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
