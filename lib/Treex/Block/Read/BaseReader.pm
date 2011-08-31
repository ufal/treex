package Treex::Block::Read::BaseReader;
use Moose;
use Treex::Core::Common;
use File::Slurp;
with 'Treex::Core::DocumentReader';
use Treex::Core::Document;

sub next_document {
    my ($self) = @_;
    return log_fatal "method next_document must be overriden in " . ref($self);
}

has selector => ( isa => 'Selector', is => 'ro', default => q{} );

has filenames => (
    isa           => 'ArrayRef[Str]',
    is            => 'ro',
    lazy_build    => 1,
    documentation => 'array of filenames to be loaded;'
        . ' automatically initialized from the attributes "from" and "filelist"',
);

has from => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'space or comma separated list of filenames to be loaded',
);

has filelist => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'a file that contains the list of filenames to be loaded, one per line',
);

has file_stem => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'how to name the loaded documents',
);

has file_number => (
    isa           => 'Int',
    is            => 'ro',
    writer        => '_set_file_number',
    default       => 0,
    init_arg      => undef,
    documentation => 'Number of input files loaded so far.',
);

has is_one_doc_per_file => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has _file_numbers => ( is => 'rw', default => sub { {} } );

sub _build_filenames {
    my $self = shift;

    log_fatal "Parameters 'from' or 'filelist' must be defined!" if !defined $self->from && !defined $self->filelist;

    my $filenames = [];

    # add all files in the 'from' parameter to the list (avoid adding STDIN if filelist is set)
    if ( $self->from && ( !$self->filelist || $self->from ne q{-} ) ) {
        push @{$filenames}, split( /[ ,]+/, $self->from );
    }

    # add all files from the filelist to the list
    if ( $self->filelist ) {
        my @list = read_file( $self->filelist );
        log_fatal 'File list ' . $self->filelist . ' cannot be loaded!' if @list == 1 && !defined( $list[0] );
        my @trimmed;
        foreach my $item (@list) {
            $item =~ s/\s*\r?\n$//;
            $item =~ s/^\s*//;
            push @trimmed, $item; # remove EOL chars, trim
        }
        push @{$filenames}, @trimmed;
    }

    # return the resulting list
    return $filenames;
}

sub current_filename {
    my ($self) = @_;
    return if $self->file_number == 0 || $self->file_number > @{ $self->filenames };
    return $self->filenames->[ $self->file_number - 1 ];
}

sub is_next_document_for_this_job {
    my ($self) = @_;
    return 1 if !$self->jobindex;
    return $self->doc_number % $self->jobs == ( $self->jobindex - 1 );
}

sub next_filename {
    my ($self) = @_;

    # In parallel processing and one_doc_per_file setting,
    # we can skip files that are not supposed to be loaded by this job/reader,
    # in order to make loading faster.
    while ( $self->is_one_doc_per_file && !$self->is_next_document_for_this_job ) {
        $self->_set_file_number( $self->file_number + 1 );
        $self->_set_doc_number( $self->doc_number + 1 );
    }
    $self->_set_file_number( $self->file_number + 1 );
    return $self->current_filename();
}

use File::Spec;

sub new_document {
    my ( $self, $load_from ) = @_;
    my $path = $self->current_filename();
    log_fatal "next_filename() must be called before new_document()" if !defined $path;
    my ( $volume, $dirs, $file ) = File::Spec->splitpath($path);
    my ( $stem, $extension ) = $file =~ /([^.]+)(\..+)?/;
    $stem =~ s/^-$/noname/;
    my %args = ( file_stem => $stem, loaded_from => $path );
    if ( defined $dirs ) {
        $args{path} = $volume . $dirs;
    }

    if ( $self->file_stem ) {
        $args{file_stem} = $self->file_stem;
    }

    if ( $self->is_one_doc_per_file && !$self->file_stem ) {
        $args{file_number} = q{};
    }
    else {
        my $num = $self->_file_numbers->{$stem};
        $self->_file_numbers->{$stem} = ++$num;
        $args{file_number} = sprintf "%03d", $num;
    }

    if ( defined $load_from ) {
        $args{filename} = $load_from;
    }

    $self->_set_doc_number( $self->doc_number + 1 );
    return Treex::Core::Document->new( \%args );
}

sub number_of_documents {
    my $self = shift;
    return $self->is_one_doc_per_file ? scalar @{ $self->filenames } : undef;
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

This class serves as an common ancestor for document readers,
that have a parameter C<from> with a space or comma separated list of filenames
to be loaded.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_filename> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item from (required, if C<filelist> is not set)

space or comma separated list of filenames, or C<-> for STDIN
(If you use this method via API you can specify C<filenames> instead.)

=item filelist (required, if C<from> is not set)

path to a file that contains a list of files to be read (one per line) 

=item file_stem (optional)

How to name the loaded documents.
This attribute will be saved to the same-named
attribute in documents and it will be used in document writers
to decide where to save the files.

=item filenames (internal)

array of filenames to be loaded,
automatically initialized from the attribute C<from>

=back

=head1 METHODS

=over

=item next_document

This method must be overriden in derived classes.
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

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
