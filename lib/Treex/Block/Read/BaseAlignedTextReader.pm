package Treex::Block::Read::BaseAlignedTextReader;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedReader';
use File::Slurp;

has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

#sub _next_filehandles {
#    my ($self) = @_;
#    my %mapping = $self->next_filenames() or return;
#    while ( my ( $lang, $filename ) = each %mapping ) {
#        my $FH;
#        if ( $filename eq '-' ) { $FH = \*STDIN; }
#        else                    { open $FH, '<:encoding(utf8)', $filename or log_fatal "Can't open $filename: $!"; }
#        $mapping{$lang} = $FH;
#    }
#    return \%mapping;
#}

sub next_document_texts {
    my ($self) = @_;

    #my $FHs = $self->_next_filehandles() or return;
    my %mapping = $self->next_filenames() or return;
    my %texts;
    if ( $self->lines_per_doc ) {    # TODO: option lines_per_document not implemented
        log_fatal "option lines_per_document not implemented for aligned readers yet";
    }
    foreach my $lang ( keys %mapping ) {
        my $filename = $mapping{$lang};
        if ( $filename eq '-' ) {
            $texts{$lang} = read_file( \*STDIN );
        }
        else {
            $texts{$lang} = read_file( $filename, binmode => 'encoding(utf8)', err_mode => 'log_fatal' );
        }
    }

    #while ( my ( $lang, $FH ) = each %{$FHs} ) {
    #    $texts{$lang} = read_file($FH);
    #}
    return \%texts;
}

1;

__END__

TODO POD
