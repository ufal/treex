package Treex::Block::Write::Treex;

use Moose;
use Treex::Core::Common;
use File::Path;
use File::Basename;

extends 'Treex::Block::Write::BaseWriter';

has '+extension' => ( default => '.treex' );
has '+compress' => ( default => 1 );

has storable => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Use the Storable module (instead of Treex::PML) for storing into .streex files. Defaults to document->storable.'
);

# HACKS: Treex::PML::Document->save() cannot take filehandle

# Allow writing to STDOUT
override '_get_filename' => sub {

    my $filename = super();

    if ( $filename eq '-' ) {
        $filename = '/dev/stdout';
    }
    return $filename;
};

# If a gzipped file is opened first, the header won't be correct
override '_open_file_handle' => sub {
    my ( $self, $filename ) = @_;
    
    # This line is the only one needed from super() implementation
    mkpath( dirname($filename) );
    return;
};

override '_document_extension' => sub {
    my ( $self, $document ) = @_;

    my $storable = $self->storable;
    if ( not defined $storable ) {
        $storable = $document->storable;
    }

    if ($storable) {
        return '.streex';
    }
    else {
        return super;
    }
};

override '_do_process_document' => sub {

    my ( $self, $document ) = @_;

    my $filename = $self->_last_filename;
    $document->set_filename($filename);
    $document->save($filename);
    return 1;
};

1;

__END__

=head1 NAME

Treex::Block::Write::Treex

=head1 DESCRIPTION

Document writer for the Treex file format (C<*.treex>),
which is actually a PML instance which is an XML-based format.

For a list of possible attributes, see 
L<BaseWriter|Treex::Block::Write::BaseWriter>.

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
