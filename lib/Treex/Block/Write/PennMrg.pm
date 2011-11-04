package Treex::Block::Write::PennMrg;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

has '+language' => ( required => 1 );

sub process_ptree {
    my ( $self, $ptree ) = @_;
    print { $self->_file_handle } "( " . $ptree->stringify_as_mrg() . " )\n";
}

1;

__END__

=head1 NAME

Treex::Block::Write::PennMrg

=head1 DESCRIPTION

Document writer for phrase-structure trees in PennTreeBank C<mrg> format.


=head1 ATTRIBUTES

=over

=item encoding

Output encoding. C<utf8> by default.

=item to

The name of the output file, STDOUT by default.

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
