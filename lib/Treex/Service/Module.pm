package Treex::Service::Module;

use Moose;
use namespace::autoclean;

has 'manager' => (
    is => 'ro',
    isa => 'Treex::Service::Manager',
    weak_ref => 1
);

has 'name' => (
    is => 'ro',
    isa => 'Str'
);

has 'fingerprint' => (
    is => 'ro',
    isa => 'Str',
    writer => 'set_fingerprint'
);

with 'Treex::Service::Role';

sub initialize {
    my ($self, $args_ref) = @_;
}

sub process {
    my ($self, $args_ref) = @_;
    return {}
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Treex::Service::Module - A base class for service modules

=head1 SYNOPSIS

   use Treex::Service::Module;
   my $module = Treex::Service::Module->new(fingerprint => 'abcd123', manager => $sm);
   $module->initialize({ ... });
   $module->process($any_input);

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
