package Treex::Service::Pool;

use Moose;
use Scalar::Util 'weaken';
use Treex::Service::Worker;
use namespace::autoclean;

has cache_size => (
    is  => 'rw',
    isa => 'Int',
    default => 5,
    trigger => \&_prune_workers
);

has workers => (
    traits  => ['Hash'],
    is  => 'ro',
    isa => 'HashRef',
    init_arg => undef,
    default => sub {{}},
    handles => {
        worker_exists => 'exists',
        workers_count => 'count',
        _clear_workers => 'clear'
    }
);

has fifo => (
    is  => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub {[]}
);

sub all_workers {
    my $self = shift;

    return map { $$_ } values %{$self->workers};
}

sub get_worker {
    my ($self, $fingerprint) = @_;

    my $w_ref = $self->workers->{$fingerprint};
    return undef unless $w_ref;

    $self->_update_fifo($fingerprint, $w_ref);
    return $$w_ref;
}

sub start_worker {
    my ($self, $args) = @_;

    return if $self->worker_exists($args->{fingerprint});

    my $worker = Treex::Service::Worker->new($args)->spawn();
    $self->set_worker($worker);

    return $worker;
}

sub set_worker {
    my ($self, $worker) = @_;

    my $workers = $self->workers;
    my $fingerprint = $worker->fingerprint;

    return $worker if $workers->{$fingerprint};
    my $worker_ref = \$worker;
    weaken($workers->{$fingerprint} = $worker_ref);
    $self->_update_fifo($fingerprint, $worker_ref);
    $self->_prune_workers;

    return $worker;
}

sub remove_worker {
    my ($self, $fingerprint) = @_;

    my $worker_ref = delete $self->workers->{$fingerprint};
    if ($worker_ref) {
        my $worker = $$worker_ref;
        $worker->despawn();
        return $worker;
    }

    return undef;
}

sub clear {
    my $self = shift;

    $self->fifo([]);
    $self->_clear_workers();
}

sub _prune_workers {
    my $self = shift;

    my $workers = $self->workers;

    while (scalar(keys %$workers) > $self->cache_size) {
        my $fp = shift(@{$self->fifo})->[0];
        delete $workers->{$fp} unless $workers->{$fp};
    }
}

sub _update_fifo {
    my ($self, $fingerprint, $worker_ref) = @_;
    my $fifo = $self->fifo;

    push @$fifo, [$fingerprint, $worker_ref];
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
