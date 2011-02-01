package Treex::Block::Write::Treex;
use Moose;
extends 'Treex::Core::Block';

has file_stem => (isa => 'Str', is => 'ro', default => 'text');

sub process_document {
    my ( $self, $document ) = @_;
    my $number = int(rand(100)); #TODO
    my $filename = $self->file_stem . '-' . $number . '.treex';
    $document->save($filename);
    return 1;
}

1;
