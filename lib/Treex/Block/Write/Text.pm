package Treex::Block::Write::Text;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

#TODO implement "to"
has to => ( isa => 'Str', is => 'ro', default => '-' );

sub process_document {
    my ( $self, $doc ) = @_;
    my $doczone = $doc->get_zone( $self->language, $self->selector );
    print $doczone->text;
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Write::Text

=head1 DESCRIPTION

Document writer for plain text format.
The text is taken from the document's attribute C<text>,
if you want to save the sentences stored in bundles,
use L<Treex::Block::Write::Sentences>.


=head1 ATTRIBUTES

=over

=item to

space or comma separated list of filenames, or C<-> for STDOUT 


=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
