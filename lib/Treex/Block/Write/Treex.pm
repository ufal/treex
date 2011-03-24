package Treex::Block::Write::Treex;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has [qw(file_stem path)] => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'overrides the attributes in documents (filled in by a DocumentReader)',
);

has to => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'space or comma separated list of filenames',
);

has filenames => (
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
    lazy_build    => 1,
    documentation => 'array of filenames where to save the documents;'
        . ' automatically initialized from the attribute "to"',
);

sub _build_filenames {
    my $self = shift;
    log_fatal "Parameter 'to' must be defined!" if !defined $self->to;
    $self->set_filenames( [ split /[ ,]+/, $self->to ] );
    return;
}

sub process_document {
    my ( $self, $document ) = @_;
    my $filename = $document->full_filename . '.treex';
    if ( defined $self->path ) {
        $document->set_path( $self->path );
        $filename = $document->full_filename . '.treex';
    }
    if ( defined $self->file_stem ) {
        $document->set_file_stem( $self->file_stem );
        $filename = $document->full_filename . '.treex';
    }
    if ( defined $self->to ) {
        my ( $next_filename, @rest_filenames ) = @{ $self->filenames };
        if ( !defined $next_filename ) {
            log_warn "There are more documents to save than filenames given ("
                . $self->to . "). Falling back to the filename filled in by a DocumentReader ($filename).";
        }
        else {
            $filename = ( defined $self->path ? $self->path : '' ) . $next_filename;
            $self->set_filenames( \@rest_filenames );
        }
    }
    log_info "Saving to $filename";
    $document->save($filename);
    return 1;
}

1;
