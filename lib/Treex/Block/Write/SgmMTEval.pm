package Treex::Block::Write::SgmMTEval;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '_doc_id' => ( is => 'rw', isa => 'Int', default => 1 );

override 'print_header' => sub {
    my ($self, $doc) = @_;

    $self->_set_doc_id(1);

    my $lang = "en";
    $lang = "cz" if ($self->language eq "cs");

    print {$self->_file_handle} "<doc docid=\"". $doc->full_filename . "\" genre=\"news\" origlang=\"$lang\">\n";
    print {$self->_file_handle} "<p>\n";
};

override 'print_footer' => sub {
    my ($self, $doc) = @_;

    print {$self->_file_handle} "</p>\n";
    print {$self->_file_handle} "</doc>\n";
};

sub process_zone {
    my ($self, $zone) = @_;

    print {$self->_file_handle} "<seg id=\"" . $self->_doc_id . "\">";
    print {$self->_file_handle} $zone->sentence;
    print {$self->_file_handle} "</seg>\n";

    $self->_set_doc_id($self->_doc_id + 1);
}

1;

__END__

=head1 NAME

Treex::Block::Write::SgmMTEval

=head1 DESCRIPTION

Generates a sgm format of sentences in a given zone. This is required by "mteval-v11b.pl" - the MT evaluation
utility.
All sentences within a single document are put inside the same paragraph.


=back

=head1 PARAMETERS

=over

=item cols

Number of columns, either 4 (form, tag, chunk, ne_type => e.g. CoNLL2003
English data) or 5 (form, lemma, tag, chunk, ne_type => e.g. CoNLL2003 German
data). Default is 4.

=item conll_labels

If 1, the system prints CoNLL2003 NE type labels, one of PER, LOC, ORG, MISC.
Default is 0, that is, original labels are printed.

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
