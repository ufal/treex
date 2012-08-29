package Treex::Block::Read::ConsumerReader;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::DocumentReader';
  use IO::Socket;
  use POE qw(Wheel::SocketFactory Wheel::ReadWrite);
  use POE qw(Component::Server::TCP Filter::Reference);
use Data::Dumper;

has port => ( is => 'rw', isa => 'Int', required => 1 );
has host => ( is => 'rw', isa => 'Str', required => 1 );

has _finished => (is => 'rw', isa => 'Bool', default => 0);

sub call {
    my ($self, $function) = @_;

    #log_warn(__PACKAGE__ . ": $function");
    #print STDERR __PACKAGE__ . ":" . __LINE__ . "\n";

    my $output = "";
    my $process = 1;


  POE::Session->create(
    inline_states => {
      _start => sub {
        # Start the server.
        $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
        RemoteAddress => $self->host,
        RemotePort    => $self->port,
          SuccessEvent => "on_client_accept",
          FailureEvent => "on_server_error",
          Filter => POE::Filter::Reference->new(),
        );

      },
      on_client_accept => sub {
        # Begin interacting with the client.
        my $client_socket = $_[ARG0];
        my $io_wheel = POE::Wheel::ReadWrite->new(
          Handle => $client_socket,
          InputEvent => "on_client_input",
          ErrorEvent => "on_client_error",
          Filter => POE::Filter::Reference->new(),
        );
        $_[HEAP]{client}{ $io_wheel->ID() } = $io_wheel;

        my $msg = $self->jobindex . "\t" . $function;
        #$_[HEAP]->{server}->put(\$msg);

        $_[HEAP]{client}{ $io_wheel->ID() }->put(\$msg);
      },
      on_server_error => sub {
        # Shut down server.
        my ($operation, $errnum, $errstr, $kernel) = @_[ARG0, ARG1, ARG2, KERNEL];
        log_warn "Server $operation error $errnum: $errstr\n";
        # 110 conenction timeout
        # 111 connection refused
        $process = 0;
        delete $_[HEAP]{server};
      },
      on_client_input => sub {
        # Handle client input.
        my ($input, $wheel_id, $kernel, $heap) = @_[ARG0, ARG1, KERNEL, HEAP];

        #log_warn(__PACKAGE__ . ": received $input");
        if ( $$input eq "__finished__" ) {
            $output = undef;
        } else {
            $output = $$input;
        }
        # print STDERR "Consumer: \n" . Data::Dumper->Dump([$output]);
        $kernel->stop();
        $process = 0;
        return;

      },
      on_client_error => sub {
        # Handle client error, including disconnect.
        my $wheel_id = $_[ARG3];
        delete $_[HEAP]{client}{$wheel_id};
        $process = 0;
      },
    }
  );

    $poe_kernel->run_while(\$process);

    return $output;
}

sub started {
    my $self = shift;
    return $self->call("cmd_started");
}

sub finished {
    my $self = shift;
    $self->_set_finished(1);
    return $self->call("cmd_finished");
}

sub is_finished
{
    my $self = shift;

    return $self->_finished;
}

sub fatalerror {
    my $self = shift;
    return $self->call("cmd_fatalerror");
}

sub next_document
{
    log_fatal("AAAAAAAAA");
}

sub number_of_documents
{
    log_fatal("AAAAAAAAA");
}


1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Block::Read::BaseTextReader - abstract ancestor for document readers

=head1 DESCRIPTION

This class serves as an common ancestor for document readers,
that have parameter C<from> with a space or comma separated list of filenames
to be loaded and load the documents from plain text files.
It is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_document_text> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item language (required)

=item lines_per_doc

If you want to split one file to more documents.
The default is 0 which means, don't split.

=item merge_files

Merge the content of all files (specified in C<from> attribute) into one stream.
Useful in combination with C<lines_per_doc> to get equally-sized documents
even from non-equally-sized files.

=item encoding

What is the encoding of the input files. E.g. C<utf8> (the default), C<cp1250> etc.

=back

=head1 METHODS

=over

=item next_document_text

Returns a content of each file (specified in C<from> attribute) as a text string.

=item next_filehandle

Helper method - you can use this instead of C<next_document_text>
if you don't want to load the whole text into memory
(but do e.g. SAX-like parsing).

=back

=head1 SEE

L<Treex::Block::Read::BaseReader>
L<Treex::Block::Read::Text>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
