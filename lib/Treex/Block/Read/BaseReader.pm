package Treex::Block::Read::BaseReader;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    return log_fatal "method next_document must be overriden in " . ref($self);
}

has selector => ( isa => 'Selector', is => 'ro', default => '' );

has filenames => (
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
    lazy_build    => 1,
    documentation => 'array of filenames to be loaded;'
        . ' automatically initialized from the attribute "from"',
);

has from => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'space or comma separated list of filenames to be loaded',
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
    log_fatal "Parameter 'from' must be defined!" if !defined $self->from;
    $self->set_filenames( [ split /[ ,]+/, $self->from ] );
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
    my %args = ( file_stem => $stem, loaded_from => $path );
    if ( defined $dirs ) {
        $args{path} = $volume . $dirs;
    }

    if ( $self->file_stem ) {
        $args{file_stem} = $self->file_stem;
    }

    if ( $self->is_one_doc_per_file && !$self->file_stem ) {
        $args{file_number} = '';
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
that have parameter C<from> with a space or comma separated list of filenames
to be loaded.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_filename> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item from (required)

space or comma separated list of filenames, or "-" for STDIN
(If you use this method via API you can specify C<filenames> instead.)

=item file_stem (optional)

How to name the loaded documents.
This will attribute will be saved to the same-named
attdibute in documents and it will be used in documents writers
to decide where to save the files.

=item filenames (internal)

array of filenames to be loaded,
automatically initialized from the attribute C<from>

=back

=head1 METHODS

=over

=item next_filename

returns the next filename (full path) to be loaded
(from the list specified in the attribute C<from>)

=item new_document($load_from?)

Returns a new empty document with pre-filled attributes
loaded_from, file_stem, file_number and path
which are guessed based on C<current_filename>.

=item current_filename

returns the last filename returned by C<next_filename> 

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Block::Read::Text>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
