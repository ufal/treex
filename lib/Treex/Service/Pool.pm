package Treex::Service::Pool;

use Moose;
use Scalar::Util 'weaken';
use Treex::Service::Worker;
use namespace::autoclean;

has cache_size => (
    is  => 'rw',
    isa => 'Int',
    default => 5
);

has workers => (
    traits  => ['Hash'],
    is  => 'ro',
    isa => 'HashRef',
    init_arg => undef,
    default => sub {{}},
    handles => {
        worker_exists => 'exists',
        all => 'values'
    }
);

has fifo => (
    is  => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub {[]}
);

sub get_worker {
    my ($self, $fingerprint) = @_;

    my $w = $self->workers->{$fingerprint};
    return undef unless $w;

    $self->_update_fifo($fingerprint, $w);
    return $w;
}

sub start_worker {
    my ($self, $args, $cb) = @_;

    return if $self->worker_exists($args->{fingerprint});

    my $worker = Treex::Service::Worker->new($args)->spawn($cb);
    $self->set_worker($worker);

    return $worker;
}

sub set_worker {
    my ($self, $worker) = @_;

    my $workers = $self->workers;
    my $fingerprint = $worker->fingerprint;

    return $worker if $workers->{$fingerprint};
    weaken($workers->{$fingerprint} = $worker);
    $self->_update_fifo($fingerprint, $worker);

    while (scalar(keys %$workers) > $self->cache_size) {
        my $exp_fp = shift(@{$self->fifo})->[0];
        delete $workers->{$exp_fp};
    }

    return $worker;
}

sub remove_worker {
    my ($self, $fingerprint) = @_;

    my $worker = delete $self->workers->{$fingerprint};
    if ($worker) {
        $worker->despawn();
    }

    return $worker;
}

sub _update_fifo {
    my ($self, $fingerprint, $worker) = @_;
    my $fifo = $self->fifo;

    push @$fifo, [$fingerprint, $worker];
    if (@$fifo >= $self->cache_size * 10) {
        my $workers = $self->workers;
        my @new_fifo;
        my %need = map { $_ => 1 } keys %$workers;
        while (%need) {
            my $fifo_entry = pop @$fifo;
            unshift @new_fifo, $fifo_entry
              if delete $need{$fifo_entry->[0]};
        }
        $self->fifo(\@new_fifo);
    }
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Pool - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Pool;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Pool,

Blah blah blah.

=head2 EXPORT

None by default.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
