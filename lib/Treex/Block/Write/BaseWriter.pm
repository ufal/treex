package Treex::Block::Write::BaseWriter;

use Moose;
use Treex::Core::Common;
use autodie;    # die if the output file cannot be opened
use File::Path;
use File::Basename;
use IO::Handle;


extends 'Treex::Core::Block';

has extension => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'Default extension for the output file type.',
    default       => ''
);

has compress => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Compression to .gz. Defaults to document->compress, or 0.'
);

has [qw(file_stem path)] => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'These provide a possibility of creating output file names from input file names.',
);

has stem_suffix => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'A suffix to append after file_stem.',
);

has to => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'The destination filename (default is "-" meaning standard output; '
        . 'use "." for the filename inherited from upstream blocks).',
);

# Experimental feature. TODO: reconsider the design and add tests
has substitute => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'A file loaded from dir1 can be saved to dir2 by substitute={dir1}{dir2}. '
        . 'You can use regex substituions, e.g. substitute={dir(\d+)/file(\d+).treex}{f\1-\2.streex}i',
);


has _filenames => (
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
    builder       => '_build_filenames',
    writer        => '_set_filenames',
    lazy_build    => 1,
    documentation => 'Array of filenames where to save the documents if using multiple files;'
        . ' automatically initialized from the attribute "to".',
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

# Return 1 if the document should be compressed (and '.gz' added to its extension). 
sub _compress_document {

    my ( $self, $document ) = @_;
    my $compress = 0;

    if ( defined $self->compress ) {
        $compress = $self->compress;
    }
    elsif ( defined $document->compress ) {
        $compress = $document->compress;
    }

    return $compress;
}

# Return the correct extension for the given document, according to the default file extension
# for the format and the compression settings.
sub _document_extension {
    my ( $self, $document ) = @_;
    return $self->extension . ( $self->_compress_document($document) ? '.gz' : '' );
}

# This just returns the next filename from the list given in the 'to' parameter. 
sub _get_next_filename {
    
    my ($self) = @_;
    
    my ( $next_filename, @rest_filenames ) = @{ $self->_filenames };    
    $self->_set_filenames( \@rest_filenames );        
    return $next_filename;     
}


# This returns the correct file name for the next document, taking the path, file_stem,
# stem_suffix and to parameters into account.
sub _get_filename {

    my ( $self, $document ) = @_;
    my $filename = $document->full_filename . $self->_document_extension($document);

    if ( defined $self->path ) {
        $document->set_path( $self->path );
        $filename = $document->full_filename . $self->_document_extension($document);
    }
    if ( defined $self->file_stem ) {
        $document->set_file_stem( $self->file_stem );
        $filename = $document->full_filename . $self->_document_extension($document);
    }
    if ( defined $self->stem_suffix ) {
        my $origstem = defined $self->file_stem
            ? $self->file_stem : $document->file_stem;
        $document->set_file_stem( $origstem . $self->stem_suffix );
        $filename = $document->full_filename . $self->_document_extension($document);
    }

    if ( defined( $self->to ) && ( $self->to ne '.' ) ) {

        my $next_filename = $self->_get_next_filename();

        if ( !defined $next_filename ) {
            log_warn "There are more documents to save than filenames given ("
                . $self->to . "). Falling back to the filename filled in by a DocumentReader ($filename).";
        }
        else {
            $filename = ( defined $self->path ? $self->path : '' ) . $next_filename;
        }
    }
    
    if (defined $self->substitute){
        my $eval_string = '$filename =~ s' . $self->substitute . ';1;';
        eval { $eval_string } or log_fatal "Failed to eval $eval_string";
        my ($fn, $directories) = fileparse($filename, $self->_document_extension($document));
        $directories =~ s{/$}{};
        $document->set_path($directories);
        $document->set_file_stem($fn);
    }

    return $filename;
}

# Default process_document method for all Writer blocks. 
override 'process_document' => sub {
    my ( $self, $document ) = @_;

    # set _file_handle properly (this MUST be called if process_document is overridden)
    $self->_prepare_file_handle($document);
    
    $self->_do_before_process($document);

    # call the original process_document with _file_handle set
    $self->_do_process_document($document);

    $self->_do_after_process($document);
    
    # This is not needed as the current file handle will be closed when opening the next file 
    # (in _prepare_file_handle) or at the end of the process.
    # However, commenting the following line leads to undeterministic errors (e.g. in en2cs)
    # UNFINISHED JOB e2c-news-dev2009-job001 PRODUCED EPILOG.
    # On the other hand, always closing the handle prevents
    # treex Read::Treex from=@my.list Write::Sentences to=out.txt
    # As a workaround I decided to close the handle only in "treex -p".
    # Martin Popel 2014
    ###
    # For some reason the scenario->runner was not defined in some cases, so
    # we test it too
    # Dusan Varis 2014
    $self->_close_file_handle() if ($self->scenario->runner && $self->scenario->runner->jobindex);
    # or if $self->scenario->runner->isa("Treex::Core::Parallel::Node")?

    return;
};

sub _do_process_document
{
    my ($self, $document) = @_;

     $self->Treex::Core::Block::process_document($document);

    return;
}

sub _do_before_process {
    my ($self, $document) = @_;

    return;
}

sub _do_after_process {
    my ($self, $document) = @_;

    return;
}

override 'process_end' => sub {
    my $self = shift;

    $self->_close_file_handle();

    return;
};

sub _close_file_handle
{
    my $self = shift;

    #log_warn("CLOSE FH: " . $self->_file_handle . "; LAST: " . $self->_last_filename);

    # close the previous one (except if it's stdout)
    if ( defined $self->_file_handle
         && ( !defined $self->_last_filename || $self->_last_filename ne "-" ) ) {
             #log_warn("CLOSE - file handle - REAL");
            close $self->_file_handle;
            $self->_set_file_handle(undef);
         }

    return;
}

# Prepare the file handle for the next file to be processed.
# This MUST be called in all process_document overrides.
sub _prepare_file_handle {
    my ( $self, $document ) = @_;

    my $filename = $self->_get_filename($document);
    
    #log_warn("PREPARE FILENAME: $filename; LAST: " . $self->_last_filename);
    #log_warn(int(defined $self->_last_filename) . " + " . int($filename eq $self->_last_filename) . " + " . $filename ne "__FAKE_OUTPUT__");

    if ( defined $self->_last_filename && $filename eq $self->_last_filename && $filename !~ "__FAKE_OUTPUT__") {

        # nothing to do, keep writing to the old filename
    }
    else {
        #  need to switch output stream

        $self->_close_file_handle();

        # open the new output stream
        log_info "Saving to $filename";
        $self->_set_file_handle( $self->_open_file_handle($filename) );
    }

    # remember last used filename
    $self->_set_last_filename($filename);
    return;
}

# Open the given file handle (including compressed variants and standard output).
sub _open_file_handle {
    my ( $self, $filename ) = @_;

    if ( $filename eq "-" ) {
        STDOUT->autoflush(1);
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
        $opn = "$filename";
    }
    mkpath( dirname($filename) );
    open ( $hdl,'>', $opn );    # we use autodie here
    $hdl->autoflush(1);
    return $hdl;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::BaseWriter

=head1 DESCRIPTION

This is the base class for document writer blocks in Treex.

It handles selecting and opening the output files, allowing for output of one-file per document.
The output file name(s) may be set in several ways (standard output may also be used as a file 
with the name '-'); GZip file compression is supported.  

Other features, such as writing all documents to one file or setting character encoding, 
are enabled in L<Treex::Block::Write::BaseTextWriter>.

=head1 PARAMETERS

=over

=item C<to>

Space-or-comma-separated list of output file names.

=item C<file_stem>, C<path>

These override the respective attributes in documents
(filled in by a L<DocumentReader|Treex::Core::DocumentReader>),
which are used for generating output file names.

=item C<stem_suffix>

A string to append after C<file_stem>.

=item C<compress>

If set to 1, the output files are compressed using GZip (if C<to> is used to set 
file names, the names must also contain the ".gz" suffix). 

=item C<clobber>

If set to 1, existing destination files will be overwritten.

=back

=head1 DERIVED CLASSES

The derived classes should just use C<print { $self->_file_handle } "output text">, the
base class will take care of opening the proper file.

All derived classes that override the C<process_document> method directly must call 
the C<_prepare_file_handle> method to gain access to the correct file handle.

The C<extension> parameter should be overriden with the default file extension
for the given file type.

=head1 TODO

=over 

=item * 

Set C<compress> if file name contains .gz or .bz2? Add .gz to extension to even for file names set with 
the C<to> parameter if C<compress> is set to true?

=item * 

Possibly rearrange somehow so that the C<_prepare_file_handle> method is not needed. The problem is that
if this was a Moose role, it would have to be applied only after an override to C<process_document>. The
Moose C<inner> and C<augment> operators are a possibility, but would not remove a need for a somewhat
non-standard behavior in derived classes (one could not just override C<process_document>, but would
have to C<augment> it). 

=back 
 
=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Bojar <bojar@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
