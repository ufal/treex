package Treex::Block::Read::BundleWildAttribute;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has from => ( is => 'ro', isa => 'Str', required => '1' );

has 'attribute' => ( is => 'ro', isa => 'Str', required => '1' );

sub process_document { 
    my ( $self, $document ) = @_;

    my $values = do $self->from;
    foreach my $bundle ( $document->get_bundles() ) {
        $bundle->wild->{$self->attribute} = shift @$values;
    }

    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Read::BundleWildAttribute

=head1 DESCRIPTION

Set bundle wild attribute values based on the input file.

The input file is in L<Data::Dumper> format, containing one array reference with one item per bundle.

To be used after L<Write::BundleWildAttributeDump>.

=head1 ATTRIBUTES

=over

=item from

filename

=item attribute

the name of the wild attribute to set

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
