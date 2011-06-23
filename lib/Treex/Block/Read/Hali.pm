package Treex::Block::Read::Hali;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has '+language' => (required=>0);

has [qw(lang1 lang2)] => (
	isa => 'LangCode',
    is => 'ro',
    required => 1,
);

has [qw(selector1 selector2)] => (
	isa => 'Selector',
    is => 'ro',
    default => '',
);


sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $document = $self->new_document();

    LINE:
    foreach my $line ( split /\n/, $text ) {
        my ($id, $align_type, $align_score, $sent1, $sent2) = split /\t/, $line;
        if ($align_type ne '1-1'){
			log_warn "align_type is not 1-1: $line";
			next LINE;
		}
        my $bundle = $document->create_bundle();
        $bundle->set_attr('czeng/id', $id);
        $bundle->set_attr('czeng/align_score', $align_score);
        $bundle->create_zone( $self->lang1, $self->selector1 )->set_sentence($sent1);
		$bundle->create_zone( $self->lang2, $self->selector2 )->set_sentence($sent2);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Hali

=head1 DESCRIPTION

Document reader for Hunalign plain text format:
one sentence per line, tab separated id, align_type, align_score,
sentence_in_language1, sentence_in_language2.
E.g.
  
  ted1	1-1	1.0	A ono je.	And it is.
  ted2	1-1	1.0	A přitom nám to dnes připadá normální.	And yet, it feels natural to us now.


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
