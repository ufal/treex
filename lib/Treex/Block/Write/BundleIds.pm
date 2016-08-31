package Treex::Block::Write::BundleIds;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

override '_do_process_document' => sub { 
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        print { $self->_file_handle } $bundle->id, "\n";
    }

    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::BundleIds

=head1 DESCRIPTION

Write bundle ids to a text file. The format of the file is one bundle id per line.

To be used before L<Read::BundleIds>.

=head1 ATTRIBUTES

=over

=item to

space or comma separated list of filenames, or C<-> for STDOUT 

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
