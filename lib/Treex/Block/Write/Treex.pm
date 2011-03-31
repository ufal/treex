package Treex::Block::Write::Treex;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has [qw(file_stem path)] => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'overrides the respective attributes in documents (filled in by a DocumentReader)',
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

__END__

=head1 NAME

Treex::Block::Write::Treex

=head1 DESCRIPTION

Document writer for the Treex file format (C<*.treex>),
which is actually a PML instance which is a XML-based format.


=head1 ATTRIBUTES

=over

=item to

space or comma separated list of filenames

=item file_stem path

overrides the respective attributes in documents (filled in by a DocumentReader)

=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
