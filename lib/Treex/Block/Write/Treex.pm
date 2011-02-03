package Treex::Block::Write::Treex;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has file_stem => (isa => 'Str', is => 'ro', default => 'text');
has count => (is => 'rw', isa=>'Int', default=>0);

sub process_document {
    my ( $self, $document ) = @_;
    $self->set_count($self->count+1);
    my $filename = sprintf "%s-%03d.treex", $self->file_stem, $self->count;
    $document->save($filename);
    return 1;
}

1;
