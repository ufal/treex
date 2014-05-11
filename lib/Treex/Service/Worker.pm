package Treex::Service::Worker;

use Moose;
use IPC::Open2;
use Storable;
use namespace::autoclean;

has [qw(fingerprint module)] => (
    is  => 'ro',
    isa => 'Str',
);

has init_args => (
    is  => 'ro',
    isa => 'Any',
);

has pid => (
    is  => 'ro',
    isa => 'Int',
    init_arg => undef,
    writer => 'set_pid'
);

sub spawn {
    my $self = shift;

    my $module = $self->module;
    my $args = freeze($self->init_args);
    my ($child_in, $child_out);
    die "Can't open child: $!"
      unless defined(my $pid = open2($child_in,
                                     $child_out,
                                     $0,
                                     '--service',
                                     "--module=$module"
                                 ));

    print $child_in $args; # pass args
    close $child_in;

    $self->set_pid($pid);
}

sub despawn {

}

sub DEMOLISH {
    my $self = shift;

    $self->despawn if $self->running;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Worker - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Worker;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Worker,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
