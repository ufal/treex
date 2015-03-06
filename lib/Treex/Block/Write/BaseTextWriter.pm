package Treex::Block::Write::BaseTextWriter;

use Moose;
use Treex::Core::Common;
use autodie;
use Encode 'decode';

extends 'Treex::Block::Write::BaseWriter';

has encoding => (
    isa           => 'Str',
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. \'utf8\' by default.',
);

has '+to' => (
    isa        => 'Maybe[Str]',
    builder    => '_build_to',
    lazy_build => 1
);

has '+compress' => (
    default => 0
);

# Set the right text encoding when opening a handle.
around '_open_file_handle' => sub {

    my ( $orig, $self, $filename ) = @_;

    # actually open the file handle
    my $handle = $self->$orig($filename);

    # set the right encoding
    binmode( $handle, ':' . $self->encoding );
    return $handle;
};

# Default to standard output if no output file is set.
sub _build_to {

    my ($self) = @_;

    if ( !defined( $self->path ) && !defined( $self->file_stem ) && !defined( $self->substitute ) ) {
        return '-';
    }
    return;
}

# Append everything to one file if the 'to' parameter is set just to one file.
override '_get_next_filename' => sub {

    my ($self) = @_;

    return $self->to if ( $self->to !~ m/[ ,]/ );
    return super();
};

sub _do_before_process {
    my ($self, $document) = @_;
    # allow header printing (in overrides)
    $self->print_header($document);

    return;
}

sub _do_after_process {
    my ($self, $document) = @_;

    # allow footer printing (in overrides)
    $self->print_footer($document);

    return;
}


sub print_header {
    my ( $self, $document ) = @_;
    return;
}

sub print_footer {
    my ( $self, $document ) = @_;
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::BaseTextWriter

=head1 DESCRIPTION

This is a base class for all text-based output formats, which adds printing to standard output
by default and the possibility to select the output file character encoding (defaulting to 
UTF-8).

Also, if multiple documents are read and only one output file given in the C<to> parameter,
all input documents will be appended to a single file.

=head1 PARAMETERS

=over 

=item C<encoding>

The output encoding, C<utf8> by default.

=back

=head1 DERIVED CLASSES

Before creating a class derived from C<BaseTextWriter>, please see the instructions in
L<Treex::Block::Write::BaseWriter>.

There is a possibility to override the following two methods in addition to those described in 
L<Treex::Block::Write::BaseWriter>:

=over

=item C<<$self->print_header($document)>>

Print a document header. Called before the standard C<process_document> is launched. Will not be
called if C<process_document> is overridden (and C<super> not called)!

=item C<<$self->print_footer($document)>>

Print a document footer. Called after the standard C<process_document> is launched. Will not be
called if C<process_document> is overridden (and C<super> not called)!

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
