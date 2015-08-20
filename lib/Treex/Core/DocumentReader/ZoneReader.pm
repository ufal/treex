package Treex::Core::DocumentReader::ZoneReader;

use Moose;
use Treex::Core::Common;
use autodie;
use File::Slurp;

has language => (
    is       => 'ro',
    isa      => 'Treex::Type::LangCode',
    required => 1,
);

has selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => '' );

sub zone_label {
    my ($self) = @_;
    return $self->language if $self->selector eq '';
    return $self->language . '_' . $self->selector;
}

has encoding      => ( isa => 'Str',  is => 'ro', default => 'utf8' );
has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );
has is_one_doc_per_file => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has filenames => (
    isa      => 'ArrayRef[Str]',
    is       => 'ro',
    required => 1,
);

has _file_number => (
    is            => 'rw',
    isa           => 'Int',
    default       => 0,
    documentation => 'Number of input files loaded so far.',
);

has _current_fh => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub restart {
    my $self = shift;
    $self->_set_file_number(0);
    return;
}

sub next_filename {
    my ($self) = @_;
    my $file_number = $self->_file_number;
    return if $file_number == @{ $self->filenames };
    $self->_set_file_number( $file_number + 1 );
    return $self->filenames->[$file_number];
}

sub current_filename {
    my ($self) = @_;
    log_fatal "next_* method must be called before" if !$self->_file_number;
    return $self->filenames->[ $self->file_number - 1 ];
}

sub _open_file {
    my ( $self, $filename ) = @_;
    return if !defined $filename;
    my $F;
    if ( $filename eq '-' ) {
        $F = \*STDIN;
    }
    else {
        open $F, '<:' . $self->encoding, $filename;
    }
    return $F;
}

sub next_filehandle {
    my ($self) = @_;
    return $self->_open_file( $self->next_filename or return );
}

sub next_document_text {
    my ($self) = @_;
    return read_file( $self->next_filehandle() or return ) if $self->is_one_doc_per_file;

    my $FH = $self->_current_fh;
    if ( !$FH ) {
        $FH = $self->next_filehandle() or return;
        $self->_set_current_fh($FH);
    }

    my $text = '';
    LINE:
    for ( 1 .. $self->lines_per_doc ) {
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

