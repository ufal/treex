package Treex::Block::Write::BundleWildAttributeDump;

use Moose;
use Treex::Core::Common;
use Data::Dumper;
extends 'Treex::Block::Write::BaseTextWriter';

has 'attribute' => ( is => 'ro', isa => 'Str', required => '1' );

override '_do_process_document' => sub { 
    my ( $self, $document ) = @_;

    my @values;
    foreach my $bundle ( $document->get_bundles() ) {
        push @values, ($bundle->wild->{$self->attribute} // {});
    }
    my $dump = Dumper(\@values);
    print { $self->_file_handle } $dump;

    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::BundleWildAttributeDump

=head1 DESCRIPTION

Dump bundle wild attribute values into a file.

The output file is in L<Data::Dumper> format, containing one array reference with one item per bundle.

To be used before L<Read::BundleWildAttribute>.


=head1 ATTRIBUTES

=over

=item to

space or comma separated list of filenames, or C<-> for STDOUT 

=item attribute

name of the attribute to write

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
