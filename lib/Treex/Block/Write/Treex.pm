package Treex::Block::Write::Treex;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has [qw(file_stem path)] => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'overrides the respective attributes in documents (filled in by a DocumentReader)',
);

has stem_suffix => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'a suffix to append after file_stem',
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

has compress => (
    is => 'rw',
    isa => 'Bool',
    default => undef,
    documentation => 'compression to .gz. If $doc->compress is undef, default is 1',
);

sub _build_filenames {
    my $self = shift;
    log_fatal "Parameter 'to' must be defined!" if !defined $self->to;
    return [ split /[ ,]+/, $self->to ];
}

sub _extension {
    my ( $self, $document ) = @_;
    my $compress = 1;
    if ( defined $self->compress ) {
        $compress = $self->compress;
    }
    elsif ( defined $document->compress ) {
        $compress = $document->compress;
    }

    return  '.treex' . ( $compress ? '.gz' : '' );
}

sub process_document {
    my ( $self, $document ) = @_;
    my $filename = $document->full_filename . $self->_extension($document);
    if ( defined $self->path ) {
        $document->set_path( $self->path );
        $filename = $document->full_filename . $self->_extension($document);;
    }
    if ( defined $self->file_stem ) {
        $document->set_file_stem( $self->file_stem );
        $filename = $document->full_filename . $self->_extension($document);;
    }
    if ( defined $self->stem_suffix ) {
        my $origstem = defined $self->file_stem
                       ? $self->file_stem : $document->file_stem;
        $document->set_file_stem( $origstem . $self->stem_suffix );
        $filename = $document->full_filename . $self->_extension($document);;
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
which is actually a PML instance which is an XML-based format.


=head1 ATTRIBUTES

=over

=item to

space or comma separated list of filenames

=item file_stem path

overrides the respective attributes in documents
(filled in by a L<DocumentReader|Treex::Core::DocumentReader>),
which are used for generating output file names

=item stem_suffix

a string to append after file_stem

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
