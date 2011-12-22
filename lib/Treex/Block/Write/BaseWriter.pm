package Treex::Block::Write::BaseWriter;

use Moose;
use Treex::Core::Common;
use autodie;    # die if the output file cannot be opened
use File::Path;
use File::Basename;

extends 'Treex::Core::Block';

has extension => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'Default extension for the output file type.',
    required      => 1
);

has compress => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Compression to .gz. Defaults to 0.'
);

has clobber => (
    isa           => 'Bool',
    is            => 'ro',
    default       => 0,
    documentation => 'allow overwriting output files',
);

has [qw(file_stem path)] => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'These provide a possibility of creating output file names from input file names.',
);

has stem_suffix => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'a suffix to append after file_stem',
);

has to => (
    isa           => 'Str',
    is            => 'ro',
    default       => '-',
    documentation => 'The destination filename (default is "-" meaning standard output; '
        . 'use "." for the filename inherited from upstream blocks).',
);

has filenames => (
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
    lazy_build    => 1,
    documentation => 'array of filenames where to save the documents;'
        . ' automatically initialized from the attribute "to"',
);

has _file_handle => (
    isa           => 'Maybe[FileHandle]',
    is            => 'rw',
    writer        => '_set_file_handle',
    documentation => 'The open output file handle.',
);

has _last_filename => (
    isa           => 'Str',
    is            => 'rw',
    writer        => '_set_last_filename',
    documentation => 'Last output filename, to keep stream open if unchanged.',
);

sub _build_filenames {
    my $self = shift;
    log_fatal "Parameter 'to' must be defined!" if !defined $self->to;
    return [ split /[ ,]+/, $self->to ];
}

sub _compress_document {

    my ( $self, $document ) = @_;
    my $compress = $self->compress;

    if ( defined $document->compress ) {
        $compress = $document->compress;
    }

    return $compress;
}

sub _document_extension {
    my ( $self, $document ) = @_;
    return $self->extension . ( $self->_compress_document($document) ? '.gz' : '' );
}

sub _get_filename {

    my ( $self, $document ) = @_;
    my $filename = $document->full_filename . ( $self->_compress_document($document) ? ".gz" : "" );

    if ( defined $self->path ) {
        $document->set_path( $self->path );
        $filename = $document->full_filename . $self->_extension($document);
    }
    if ( defined $self->file_stem ) {
        $document->set_file_stem( $self->file_stem );
        $filename = $document->full_filename . $self->_extension($document);
    }
    if ( defined $self->stem_suffix ) {
        my $origstem = defined $self->file_stem
            ? $self->file_stem : $document->file_stem;
        $document->set_file_stem( $origstem . $self->stem_suffix );
        $filename = $document->full_filename . $self->_extension($document);
    }

    if ( defined $self->to && $self->to ne "." ) {
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

    return $filename;
}

around 'process_document' => sub {

    my ( $orig, $self, $document ) = @_;

    my $filename = $self->_get_filename($document);

    if ( defined $self->_last_filename && $filename eq $self->_last_filename ) {

        # nothing to do, keep writing to the old filename
    }
    else {

        #  need to switch output stream
        close $self->_file_handle
            if defined $self->_file_handle
                && ( !defined $self->_last_filename || $self->_last_filename ne "-" );

        # open the new output stream
        log_info "Saving to $filename";
        log_fatal "Won't overwrite $filename (use clobber=1 to force)."
            if !$self->clobber && -e $filename;
        $self->_set_file_handle( $self->_open_file_handle($filename) );
    }

    # remember last used filename
    $self->_set_last_filename($filename);

    # call the main process_document with _file_handle set
    $self->$orig(@_);
    return;
};

sub _open_file_handle {

    my ( $self, $filename ) = @_;

    if ( $filename eq "-" ) {
        return \*STDOUT;
    }

    my $opn;
    my $hdl;

    # file might not recognize some files!
    if ( $filename =~ /\.gz$/ ) {
        $opn = "| gzip -c > '$filename'";
    }
    elsif ( $filename =~ /\.bz2$/ ) {
        $opn = "| bzip2 > '$filename'";
    }
    else {
        $opn = ">$filename";
    }
    mkpath( dirname($filename) );
    open $hdl, $opn;    # we use autodie
    return $hdl;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::BaseWriter

=head1 DESCRIPTION

This is the base class for document writers in Treex.

It contains just the C<to> attribute, which is used for the target file name (or names, if overrides are used)

=head1 PARAMETERS

=over

=item C<to>

The name of the output file, STDOUT by default.

If this role is used together with the L<Treex::Block::Write::MultipleFiles> role, its own list of files is 
taken into account.

=item C<encoding>

The output encoding, C<utf8> by default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
