package Treex::Block::Read::BaseAlignedTextReader;
use Moose;
use Treex::Common;
extends 'Treex::Block::Read::BaseAlignedReader';

has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

sub BUILD {
    my ($self) = @_;
    if ( $self->lines_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub next_filehandles {
    my ($self) = @_;
    my %mapping = $self->next_filenames() or return;
    while ( my ( $lang, $filename ) = each %mapping ) {
        my $FH;
        if ( $filename eq '-' ) { $FH = *STDIN; }
        else                    { open $FH, '<:utf8', $filename or die "Can't open $filename: $!"; }
        $mapping{$lang} = $FH;
    }
    return \%mapping;
}

sub next_document_texts {
    my ($self) = @_;
    my $FHs = $self->next_filehandles() or return;

    my %texts;
    if ( $self->lines_per_doc ) {    # TODO: option lines_per_document not implemented
        log_fatal "option lines_per_document not implemented for aligned readers yet";
    }

    while ( my ( $lang, $FH ) = each %{$FHs} ) {
        $texts{$lang} = join '', <$FH>;
    }
    return \%texts;
}

1;
