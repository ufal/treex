package Treex::Block::Write::Treex;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseWriter';

has '+extension' => ( default => '.treex' );

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
    return undef;
};

sub process_document {

    my ( $self, $document ) = @_;

    # prepare the correct file name    
    $self->_prepare_file_handle( $document );

    $document->save( $self->_last_filename );
    return 1;
}

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
