package Treex::Block::Read::BaseAlignedTextReader;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseAlignedReader';

has lines_per_document => ( isa => 'Int', is => 'ro', default => 0 );
has merge_files => ( isa => 'Bool', is => 'ro', default => 0 );

has _current_fhs => (is=> 'rw');

sub next_filehandles {
    my ($self) = @_;
    my %mapping = $self->next_filenames() or return;
    while (my ($lang, $filename) = each %mapping){
        my $FH;
        if ($filename eq '-') { $FH = *STDIN;}
        else {open $FH, '<:utf8', $filename or die "Can't open $filename: $!";}
        $mapping{$lang} = $FH;
    }   
    return \%mapping;
}

sub next_document_texts {
    my ($self) = @_;
    my $FHs = $self->_current_fhs;
    if (!$FHs) {
        $FHs = $self->next_filehandles() or return;
        $self->_set_current_fhs($FHs);
    }
    
    my %texts;
    if ($self->lines_per_document){ # TODO: option lines_per_document not implemented
        log_fatal "option lines_per_document not implemented for aligned readers yet";
    }
    
    while (my ($lang, $FH) = each %{$FHs}){
        $texts{$lang} = join '', <$FH>;
    }
    $self->_set_current_fhs($self->next_filehandles());
    return \%texts;
}

1;
