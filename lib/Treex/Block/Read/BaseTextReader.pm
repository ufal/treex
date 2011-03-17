package Treex::Block::Read::BaseTextReader;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';
use File::Slurp;

# By default read from STDIN
has '+from' => ( default => '-' );

has language => ( isa => 'LangCode', is => 'ro', required => 1 );
has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

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
    open my $FH, '<:utf8', $filename or die "Can't open $filename: $!";
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
