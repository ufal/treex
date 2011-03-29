package Treex::Block::Read::Treex;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';

sub next_document {
    my ($self) = @_;
    my $filename = $self->next_filename() or return;
    return $self->new_document($filename);
}

1;

__END__

=head1 NAME

Treex::Block::Read::Treex

=head1 DESCRIPTION

Document reader for the Treex file format (C<*.treex>),
which is actually a PML instance which is a XML-based format.


=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README