package Treex::Service::EventEmitter;

use Moose;
use Scalar::Util qw(blessed weaken);
use Treex::Core::Log;
use namespace::autoclean;

use constant DEBUG => $ENV{TS_EVENTS_DEBUG} || 0;

has events => (
    is  => 'ro',
    isa => 'HashRef[ArrayRef[CodeRef]]',
    default => sub {{}},
);

sub emit {
    my ($self, $name) = (shift, shift);

    if (my $subscribers = $self->events->{$name}) {
        log_debug "-- Emit $name in @{[blessed $self]} (@{[scalar @$subscribers]})\n" if DEBUG;
        for my $cb (@$subscribers) {
            $self->$cb(@_);
        }
    } else {
        log_debug "-- Emit $name in @{[blessed $self]} (0)\n" if DEBUG;
        die "@{[blessed $self]}: $_[0]" if $name eq 'error';
    }

    return $self;
}

sub emit_safe {
    my ($self, $name) = (shift, shift);

    if (my $s = $self->events->{$name}) {
        log_debug "-- Emit $name in @{[blessed $self]} safely (@{[scalar @$s]})\n"
          if DEBUG;
        for my $cb (@$s) {
            $self->emit(error => qq{Event "$name" failed: $@})
              unless eval { $self->$cb(@_); 1 };
        }
    } else {
        log_debug "-- Emit $name in @{[blessed $self]} safely (0)\n" if DEBUG;
        die "@{[blessed $self]}: $_[0]" if $name eq 'error';
    }

    return $self;
}

sub subscribers { shift->events->{shift()} || [] }

sub has_subscribers { !!@{shift->subscribers(shift)} }

sub on {
    my ($self, $name, $cb) = @_;
    push @{$self->events->{$name} ||= []}, $cb;
    return $cb;
}

sub once {
    my ($self, $name, $cb) = @_;

    weaken $self;
    my $wrapper;
    $wrapper = sub {
        $self->unsubscribe($name => $wrapper);
        $cb->(@_);
    };
    $self->on($name => $wrapper);
    weaken $wrapper;

    return $wrapper;
}

sub unsubscribe {
    my ($self, $name, $cb) = @_;

    # One
    if ($cb) {
        $self->events->{$name} = [grep { $cb ne $_ } @{$self->events->{$name}}];
        delete $self->events->{$name} unless @{$self->events->{$name}};
    }

    # All
    else {
        delete $self->events->{$name};
    }

    return $self;
}


__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::EventEmitter - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::EventEmitter;
   blah blah blah

=head1 DESCRIPTION

L<Treex::Service::EventEmitter> is a simple base class for event emitting objects.

Inspired by L<Mojo::EventEmitter>

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
