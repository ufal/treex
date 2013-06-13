package Treex::Block::Read::BaseReader;
use Moose;
use Treex::Core::Common;
use File::Slurp;
with 'Treex::Core::DocumentReader';
use Treex::Core::Document;

sub next_document {
    my ($self) = @_;
    return log_fatal "method next_document must be overridden in " . ref($self);
}

# Default language is und (undetermined/unknown) and selector empty.
has selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has language => ( isa => 'Treex::Type::LangCode', is => 'ro', default => 'und' );


has from => (
    isa           => 'Treex::Core::Files',
    is            => 'rw',
    coerce        => 1,
    required      => 1,
    handles       => [qw(current_filename file_number _set_file_number)],
    documentation => 'arrayref of filenames to be loaded, '
        . 'coerced from a space or comma separated list of filenames, '
        . 'see POD for details',
);

has file_stem => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'how to name the loaded documents',
);

has is_one_doc_per_file => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has _file_numbers => ( is => 'rw', default => sub { {} } );

sub next_filename {
    my ($self) = @_;

    # return undef, but do not move further if we are at the end of document list (we might need the current file name)
    return if ( $self->file_number >= $self->from->number_of_files );

    $self->_set_file_number( $self->file_number + 1 );
    return $self->current_filename();
}

use File::Spec;

sub new_document {
    my ( $self, $load_from ) = @_;
    my $path = $self->current_filename();
    log_fatal "next_filename() must be called before new_document()" if !defined $path;
    my ( $volume, $dirs, $file ) = File::Spec->splitpath($path);

    # Delete file extension, e.g.
    # file.01.conll -> file.01
    # cs42.treex.gz -> cs42
    $file =~ s/\.[^.]+(\.gz)?$//;

    # Substitute standard input for noname.
    $file =~ s/^-$/noname/;

    my %args = ( file_stem => $file, loaded_from => $path );
    if ( defined $dirs ) {
        $args{path} = $volume . $dirs;
    }

    # Override the naming heuristics above, if file_stem was specified.
    if ( $self->file_stem ) {
        $args{file_stem} = $self->file_stem;
    }

    if ( $self->is_one_doc_per_file && !$self->file_stem ) {
        $args{file_number} = q{};
    }
    else {
        my $num = $self->_file_numbers->{$file};
        $self->_file_numbers->{$file} = ++$num;
        $args{file_number} = sprintf "%03d", $num;
    }

    if ( defined $load_from ) {
        $args{filename} = $load_from;
    }

    $self->_set_doc_number( $self->doc_number + 1 );

    my $document;
    if ( defined $load_from and $load_from =~ /\.streex$/ ) {
        $document = Treex::Core::Document->retrieve_storable($load_from);
        $document->set_storable(1);
    }
    else {
        $document = Treex::Core::Document->new( \%args );
    }

    if ( defined $load_from && $load_from =~ /\.gz$/ ) {
        $document->set_compress(1);
    }

    return $document;
}

sub number_of_documents {
    my $self = shift;
    return $self->is_one_doc_per_file ? $self->from->number_of_files : undef;
}

after 'restart' => sub {
    my $self = shift;
    $self->_set_file_number(0);
};

1;

__END__

=head1 NAME

Treex::Block::Read::BaseReader - abstract ancestor for document readers

=head1 DESCRIPTION

This class serves as a common ancestor for document readers
that have the parameter C<from> with a space or comma separated list of filenames
to be loaded.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_filename> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item from (required)

space or comma separated list of filenames, or C<-> for STDIN

An '@' directly in front of a file name causes this file to be interpreted as a file
list, with one file name per line, e.g. '@filelist.txt' causes the reader to open
'filelist.txt' and read a list of files from it. File lists may be arbitrarily
mixed with regular files in the parameter.

Similarly, you can use I<!> for wildcard expansion, e.g.
C<treex -Len Read::Treex from='!dir??/file*.txt'>.
The single quotes are needed for two reasons.
First, to prevent bash from interpreting the wildcard characters.
Second, to prevent bash from interpreting the exclamation mark as history expansion.

The I<@filelist> and I<!wildcard> conventions are used in several tools, e.g. 7z or javac.

(If you use this method via API you can specify a string array reference or a
L<Treex::Core::Files> object.)

=item file_stem (optional)

How to name the loaded documents.
This attribute will be saved to the same-named
attribute in documents and it will be used in document writers
to decide where to save the files.

=back

=head1 METHODS

=over

=item next_document

This method must be overridden in derived classes.
(The implementation in this class just issues fatal error.)

=item next_filename

returns the next filename (full path) to be loaded
(from the list specified in the attribute C<from>)

=item new_document($load_from?)

Returns a new empty document with pre-filled attributes
C<loaded_from>, C<file_stem>, C<file_number> and C<path>
which are guessed based on C<current_filename>.

=item current_filename

returns the last filename returned by C<next_filename>

=item is_next_document_for_this_job

Is the document that will be returned by C<next_document>
supposed to be processed by this job?
This is relevant only in parallel processing,
where each job has a different C<$jobnumber> assigned.

=item number_of_documents

Returns the number of documents that will be read by this reader.
If C<is_one_doc_per_file> returns C<true>, then the number of documents
equals the number of files given in C<from>.
Otherwise, this method returns C<undef>.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Block::Read::Text>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
