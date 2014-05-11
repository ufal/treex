package Treex::Service::Manager::Transaction;

use Mojo::Base 'Mojo::EventEmitter';
use Storable;

has [qw(input output connection)];

sub server_read {
    my ($self, $chunk) = @_;
    $self->input(ref $chunk ? $chunk : thaw($chunk));
    $self->{state} ||= 'read';
    $self->emit('request');
}

sub server_write {
    my $self = shift;
    return freeze({error => $self->error}) if $self->error;
    return freeze($self->output || []);
}

sub error {
    my $self = shift;

    if (@_) {
        $self->{error} = shift;
        $self->resume;
    } else {
        return $self->{error};
    }
}

sub clear_error { delete $_[0]->{error} }

sub resume {
    my $self = shift;

    $self->{state} = 'write';
    $self->emit('resume');
}

1;
__END__

=head1 NAME

Treex::Service::Manager::Transaction - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Manager::Transaction;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Manager::Transaction,

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
