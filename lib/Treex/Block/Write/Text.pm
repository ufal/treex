package Treex::Block::Write::Text;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );

override '_do_process_document' => sub { 
    my ( $self, $doc ) = @_;

    foreach my $doczone ($self->get_selected_zones($doc->get_all_zones())){
        print { $self->_file_handle } $doczone->text;
    }  
    return;
};

1;

__END__

=head1 NAME

Treex::Block::Write::Text

=head1 DESCRIPTION

Document writer for plain text format.
The text is taken from the document's attribute C<text>,
if you want to save the sentences stored in L<bundles|Treex::Core::Bundle>,
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

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
