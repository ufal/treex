package Treex::Block::Read::BaseCoNLLReader;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document_text {
    my ($self) = @_;
    return $self->from->next_file_text() if $self->is_one_doc_per_file;

    my $text = '';
    my $empty_lines = 0;
    LINE:
    while(1){
        my $line = $self->from->next_line();
        if (!defined $line){
            return if $text eq '' && !$self->from->has_next_file();
            last LINE;
        }
        if ( $line =~ m/^\s*$/ ) {
            $empty_lines++;
            return $text if $empty_lines == $self->lines_per_doc;
        }
        $text .= $line;
    }
    return $text;
}


1;

__END__

=head1 NAME

Treex::Block::Read::BaseCoNLLReader

=head1 DESCRIPTION

Base class for reading CoNLL-like files (with one token per line, sentences
separated by empty lines).

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

=back

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Dan Zeman <zeman@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
