package Treex::Block::Read::BundleIds;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has from => ( is => 'rw', isa => 'Str', default => 'bundle_ids.txt' );

sub process_document { 
    my ( $self, $document ) = @_;

    my @ids;
    {
        open my $file, '<', $self->from;
        my $line;
        while ($line = <$file>) {
            chomp $line;
            push @ids, $line;
        }
        close $file;
    }
    foreach my $bundle ( $document->get_bundles() ) {
        $bundle->set_id(shift @ids);
    }

    return;
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Read::BundleIds

=head1 DESCRIPTION

Read bundle ids from a text file, changing the original bundle ids to the newly read ones. The format of the file is one bundle id per line.

To be used after L<Write::BundleIds>.

=head1 ATTRIBUTES

=over

=item from

filename

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
