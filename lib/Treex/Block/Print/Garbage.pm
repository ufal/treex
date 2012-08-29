package Treex::Block::Print::Garbage;
use Moose;

use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';

has 'size' => ( isa => 'Num', is => 'ro', required => 1 );


override '_do_process_document' => sub {

    my ( $self, $doc ) = @_;

    print { $self->_file_handle } 'a' x ( $self->{size} * 1e6) . "\n";
    log_warn(__PACKAGE__);
    log_warn(__PACKAGE__);

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Garbage

=head1 DESCRIPTION

This block prints X MB of texts.

=head1 PARAMETERS

=over

=item C<size>

Amount of printed text in MB. This parameter is required.

=head1 AUTHOR

Martin Majlis <majlis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
