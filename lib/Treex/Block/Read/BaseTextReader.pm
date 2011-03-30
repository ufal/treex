package Treex::Block::Read::BaseTextReader;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use File::Slurp;

# By default read from STDIN
has '+from' => ( default => '-' );

has language      => ( isa => 'LangCode', is => 'ro', required => 1 );
has lines_per_doc => ( isa => 'Int',      is => 'ro', default  => 0 );
has merge_files   => ( isa => 'Bool',     is => 'ro', default  => 0 );

has _current_fh => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub next_filehandle {
    my ($self) = @_;
    my $filename = $self->next_filename();
    return if !defined $filename;
    return \*STDIN if $filename eq '-';
    open my $FH, '<:utf8', $filename or log_fatal "Can't open $filename: $!";
    return $FH;
}

sub next_document_text {
    my ($self) = @_;
    my $FH = $self->_current_fh;
    if ( !$FH ) {
        $FH = $self->next_filehandle() or return;
        $self->_set_current_fh($FH);
    }

    if ( $self->is_one_doc_per_file ) {
        $self->_set_current_fh(undef);
        return read_file($FH);
    }

    my $text = '';
    LINE:
    for my $line ( 1 .. $self->lines_per_doc ) {
        while ( eof($FH) ) {
            $FH = $self->next_filehandle();
            if ( !$FH ) {
                return if $text eq '';
                return $text;
            }
            $self->_set_current_fh($FH);
            last LINE if !$self->merge_files;
        }
        $text .= <$FH>;
    }
    return $text;
}

1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Block::Read::BaseTextReader - abstract ancestor for document readers

=head1 DESCRIPTION

This class serves as an common ancestor for document readers,
that have parameter C<from> with a space or comma separated list of filenames
to be loaded and load the documents from plain text files.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_document_text> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item language (required)

=item lines_per_doc

If you want to split one file to more documents.
The default is 0 which means, don't split.

=item merge_file

Merge the content of all files (specified in C<from> attribute) into one stream.
Useful in combination with C<lines_per_doc> to get equally-sized documents
even from non-equally-sized files.

=back

=head1 METHODS

=over

=item next_document_text

Returns a content of each file (specified in C<from> attribute) as a text string.

=item next_filehandle

Helper method - you can use this instead of C<next_document_text>
if you don't want to load the whole text into memory
(but do e.g. SAX-like parsing).

=back

=head1 SEE

L<Treex::Block::Read::BaseReader>
L<Treex::Block::Read::Text>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
