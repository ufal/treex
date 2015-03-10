#!/usr/bin/env perl 

use 5.010;
use strict;
use warnings;

use utf8;
use RPC::XML;
use RPC::XML::Server;
use POSIX "strftime";
use Getopt::Long;
use JSON;
use UUID::Generator::PurePerl;
use Time::HiRes;

$RPC::XML::ENCODING = 'utf-8';

my $USAGE = "Usage: $0 <-p port> <-s socket-port>";

#
# Prepare IO handles
#

binmode( STDIN,  ":utf8" );
binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );
STDERR->autoflush(1);
STDOUT->autoflush(1);

#
# Read configuration options
#

my $max_input_length = 100000;
my $host             = "localhost";
my $port             = 0;
my $socket_port      = 0;

GetOptions(
    'port|p=i'        => \$port,
    'socket-port|s=i' => \$socket_port,
) or die($USAGE);

die($USAGE) if ( !$port or !$socket_port );

#
# Initialize XMLRPC server and UUID generator
#

my $server = RPC::XML::Server->new( host => $host, port => $port );

$server->add_method(
    {   name      => 'process_task',
        signature => ['struct struct'],    # input & return type
        code      => \&process_task,
    }
);

my $uuid_gen = UUID::Generator::PurePerl->new();

log_message("Worker started on port $port, expecting socket server on port $socket_port");

#
# Main loop
#

$server->server_loop();

#
# Functions
#

# This is the main function called in the server loop
sub process_task {
    my ( $server, $task ) = @_;

    # check for invalid inputs
    if ( $task->{action} ne 'translate' ) {
        return { 'error' => 'Unknown action: ' . $task->{action} };
    }
    elsif ( !defined( $task->{text} ) ) {
        return { 'error' => 'No text to translate.' };
    }
    elsif ( length( $task->{text} ) > $max_input_length ) {
        return { 'error' => 'The MT system could not translate your request.' };
    }

    # translate the request
    else {
        return translate( $task->{text}, $task->{detokenize} // '', $task->{alignmentInfo} // '' );
    }
}

# Main translation function, calls socket translation and wraps the result.
sub translate {

    my ( $txt, $detok, $alignment ) = @_;
    $txt =~ s/[\r\n\s]+/ /g;

    log_message("Translation request: $txt");
    
    # call the actual translation + measure time taken to obtain it
    my ( $start_sec, $start_msec ) = Time::HiRes::gettimeofday();
    my $res = socket_translate($txt);
    my ( $stop_sec, $stop_msec ) = Time::HiRes::gettimeofday();

    # generate translation ID
    my $uuid = $uuid_gen->generate_v4();
    $uuid = $uuid->as_string();
    $uuid =~ s/-//g;

    # format the result according to MTMonkey API for each sentence
    # check options for detokenization, returning source tokenization
    # (TODO: alignment and n-best lists are ignored)
    $detok = ( $detok !~ /^(false|f|no|n|0)$/i );
    my $ret_src_tok = ( @$res > 1 ) | ( $alignment =~ /^(true|t|yes|y|1)$/i );
    my @transl_sents;
    my $errors = 0;
    foreach my $sent (@$res) {

        my $transl_sent;

        # check if the sentence was actually translated and add it to results
        # we assume that the result must be non-empty if the input is empty, otherwise there has been an error
        if ( $sent->{trg_txt} or not $sent->{src_tok} ) {
            $transl_sent = {
                'translated' => [
                    {
                        'text' => ( $detok ? $sent->{trg_txt} : $sent->{trg_tok} ),
                        'score' => 1,
                        'rank'  => 0,
                    }
                ],
            };
            if ($ret_src_tok) {    # add source tokenized sentence
                $transl_sent->{'src-tokenized'} = $sent->{src_tok};
            }
        }

        # if there was an error translating this sentence, report it
        else {
            $transl_sent = {
                'errorMessage' => 'Moses could not translate this sentence.',
                'errorCode'    => 1,
                }
        }
        push @transl_sents, $transl_sent;
    }

    # compose a MTMonkey-compliant response
    my $ret = {
        'timeWork' => ( $stop_sec - $start_sec + 1e-6 * ( $stop_msec - $start_msec ) ) . 's',
        'translation'   => \@transl_sents,
        'translationId' => $uuid,
    };
    if ($errors) {
        $ret->{errorCode}    = 99;
        $ret->{errorMessage} = "Could not translate $errors sentence(s).";
    }

    log_message( "Error code: " . ( $ret->{errorCode} // 0 ) );
    return $ret;
}

# This calls the Treex socket server to translate the requested text
sub socket_translate {

    my ($source_text) = @_;

    # connect to Treex socket server
    my $remote = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => "localhost",
        PeerPort => $socket_port,
    ) or die "Cannot connect to port $socket_port at localhost.";

    binmode( $remote, ":utf8" );

    # send paragraph to the server
    print $remote "$source_text\n";

    # retrieve translation
    my $result = <$remote>;

    # close connection to the server
    close $remote;

    return decode_json($result);
}

# Logging
sub log_message {
    my ($message) = @_;
    my $time = strftime "%x %H:%M:%S", localtime;
    print STDERR "TREEX-WORKER ", $time, ": ", $message, "\n";
}

__END__

=encoding utf-8

=head1 NAME

treex-mtmworker.pl – an MTMonkey worker for Treex

=head1 DESCRIPTION

This script functions as an MTMonkey L<http://github.com/ufal/mtmonkey> worker
for Treex. It uses the Treex socket server (C<treex-socket-server.pl>) and wraps
its results in MTMonkey-compliant XML. 

Run C<treex-socket-server.pl> on a given port with your desired translation
scenario and set the C<--detail> option (returning detailed results). Then you
can run this script, pointing it to the socket server's port.

You can then set your MTMonkey appserver to point to this worker.

=head1 SYNOPSIS

  treex-socket-server.pl --port=5001 --src_zone=en:src --trg_zone=cs:tst --scenario=translate.scen &
  treex-mtmwoker.pl --port=7001 --socket-port=5001 &
  
=head1 PARAMETERS

=over

=item port

The TCP port on which this worker will start.

=item socket-port

The TCP port on which the Treex socket server is running. 

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Ondřej Bojar <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
