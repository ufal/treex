package Treex::Block::Write::ViewJSON;

use Moose;
use namespace::autoclean;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.json' );

has pretty => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Format JSON to be pretty. Defaults to 0.'
);

eval {
    require Treex::View;
};
if ($@) {
    die <<"MSG";

Please install Treex::View package for Write::ViewJSON block to work correctly

cpanm -n Treex::View

MSG
}

has treex_view => (
    is => 'ro',
    isa => 'Treex::View',
    default => sub { Treex::View->new }
);

override '_do_process_document' => sub {
    my ( $self, $document ) = @_;

    print { $self->_file_handle() } $self->treex_view->convert($document, $self->pretty);
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
