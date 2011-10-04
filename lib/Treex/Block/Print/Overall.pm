package Treex::Block::Print::Overall;
use Moose::Role;


has 'overall' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

requires '_reset_stats';
requires '_print_stats';
requires 'process_bundle';


# Prints the whole statistics at the end of the process
sub process_end {

    my ($self) = @_;

    if ( $self->overall ) {
        $self->_print_stats();
    }
    return;
}

sub process_document {

    my ( $self, $document ) = @_;

    if ( !$self->overall ) {
        $self->_reset_stats();
    }        

    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }

    if ( !$self->overall ) {
        $self->_print_stats();
    }    

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Overall

=head1 DESCRIPTION

A Moose role for blocks that are able to print some results either for each single document
or overall for all documents processed.

=head1 ATTRIBUTES

=over

=item C<overall>

If this is set to 1, an overall statistics for all the processed documents is printed instead of a score for each single
document.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
