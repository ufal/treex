package Treex::Block::Read::BasePlainReader;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';

# By default read from STDIN
has '+from' => (default => '-');

has lines_per_document => ( isa => 'Int', is => 'ro', default => 50 );
has merge_files => ( isa => 'Bool', is => 'ro', default => 0 );

has _current_fh => (is=> 'rw');

sub next_filehandle {
    my ($self) = @_;
    my $filename = $self->next_filename() or return;
    return *STDIN if $filename eq '-';
    open my $FH, '<:utf8', $filename or die "Can't open $filename: $!";
    return $FH;
}

sub next_document_text {
    my ($self) = @_;
    my $FH = $self->_current_fh;
    if (!$FH) {
        $FH = $self->next_filehandle() or return;
        $self->_set_current_fh($FH);
    }
    
    my $text = '';
    LINE:
    for my $line ( 1 .. $self->lines_per_document ) {
        while (eof($FH)){
            $FH = $self->next_filehandle();
            if (!$FH){
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
