#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use IO::Socket;
use POSIX qw(strftime);
use IO::Handle;
use Getopt::Long;
use JSON;

use Treex::Core::Common;
use Treex::Core::Scenario;
use Treex::Core::Document;

my $USAGE = "Usage: $0 --port=XXXX --source_zone=lang:sel --target_zone=lang:sel --scenario=path/to/file.scen";

#
# Get configuration from command line
#

my $port      = 0;
my $scen_file = undef;
my $src_zone  = undef;
my $trg_zone  = undef;
my $detail    = 0;

GetOptions(
    'port|p=i'                                 => \$port,
    'source_zone|source|src_zone|src|from|f=s' => \$src_zone,
    'target_zone|target|trg_zone|trg|to|t=s'   => \$trg_zone,
    'scenario|scen|s=s'                        => \$scen_file,
    'detailed_result|detail|d'                 => \$detail,
) or die($USAGE);

die "Port not set.\n$USAGE"          if ( !$port );
die "Source zone not set.\n$USAGE"   if ( !$src_zone );
die "Target zone not set.\n$USAGE"   if ( !$src_zone );
die "Scenario file not set.\n$USAGE" if ( !$scen_file );

my ( $src_lang, $src_sel ) = split /[:_]/, $src_zone;
my ( $trg_lang, $trg_sel ) = split /[:_]/, $trg_zone;

#
# Run the server
#

# initialize the scenario
my $scenario = Treex::Core::Scenario->new( { 'from_file' => $scen_file } );
$scenario->start();

# initialize the socket server
my $server = IO::Socket::INET->new(
    Proto     => 'tcp',
    LocalPort => $port,
    Listen    => SOMAXCONN,
    Reuse     => 1
);
die "Can't setup server" if ( !$server );
binmode( $server, ':utf8' );

# initialize logging
binmode( STDERR, ':utf8' );
STDERR->autoflush(1);
log_message("Listening on port $port, scenario $scen_file ($src_zone -> $trg_zone).");

# the main server loop
while ( my $client = $server->accept() ) {

    binmode( $client, ":utf8" );
    $client->autoflush(1);

    while ( my $src_txt = <$client> ) {

        # pre-process the client request
        $src_txt =~ s/[\r\n\s]+/ /g;
        $src_txt =~ s/^\s+//;
        $src_txt =~ s/\s+$//;

        log_message("REQ\t$src_txt");

        # create a Treex document, insert the source text into it and apply the scenario
        my $document = Treex::Core::Document->new();
        my $bundle   = $document->create_bundle();
        my $zone     = $bundle->create_zone( $src_lang, $src_sel );
        $zone->set_sentence($src_txt);

        $scenario->apply_to_documents($document);

        # retrieve the translated result from the Treex document
        my @src_tok;
        my @trg_tok;
        my @trg_txt;
        
        foreach my $bundle ( $document->get_bundles ) {

            # get source and target zone
            my $src_zone = $bundle->get_zone( $src_lang, $src_sel );
            my $trg_zone = $bundle->get_zone( $trg_lang, $trg_sel );
            
            log_message("ERR Undefined source zone.") if (!$src_zone);
            log_message("ERR Undefined target zone.") if (!$trg_zone);

            # get tokenized source, tokenized target, and de-tokenized target
            my $src_tok_sent = $src_zone ? get_tokenized($src_zone) : '';
            my $trg_tok_sent = $trg_zone ? get_tokenized($trg_zone) : '';
            my $trg_sent     = $trg_zone ? $trg_zone->sentence : '';
            
            push @src_tok, $src_tok_sent // '';
            push @trg_tok, $trg_tok_sent // '';
            push @trg_txt, $trg_sent     // '';
        }

        # return the result to the client
        print $client encode_result( $src_txt, \@src_tok, \@trg_tok, \@trg_txt ) . "\n";

        log_message( "RES\t$src_txt\t" . join( " ", @trg_txt ) );
    }
    close $client;
}

#
# Helper helper functions
#

# log a message to STDOUT, prepending it with a timestamp
sub log_message {
    my ($message) = @_;
    my $time = strftime "%x %H:%M:%S", localtime;
    print STDERR "TREEX-SERVER ", $time, ": ", $message, "\n";
}

sub get_tokenized {
    my ($zone) = @_;
    return '' if ( !$zone->has_atree );
    return join( ' ', map { $_->form // '' } $zone->get_atree()->get_descendants( { ordered => 1 } ) );
}

sub fix_spaces {
    my ($str) = @_;
    $str =~ s/[\s\n\r]+/ /g;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

sub encode_result {
    my ( $src_txt, $src_tok, $trg_tok, $trg_txt ) = @_;
    if ( !$detail ) {
        return join( " ", map { fix_spaces($_) } @$trg_txt );
    }

    my @ret;

    for ( my $i = 0; $i < @$src_tok; ++$i ) {
        push @ret, {
            'src_tok' => fix_spaces( $src_tok->[$i] ),
            'trg_tok' => fix_spaces( $trg_tok->[$i] ),
            'trg_txt' => fix_spaces( $trg_txt->[$i] ),
        };
    }
    return encode_json( \@ret );
}

__END__

=encoding utf-8

=head1 NAME

treex-socket-server.pl – running a Treex scenario in a socket server

=head1 DESCRIPTION

This script runs a Treex scenario as a socket server, servicing requests for processing
plain text sentences in a serial way. 

To run Treex as a socket server, use any scenario file C<.scen> that accepts
sentences on the input and saves the output in each bundle's C<sentence> attribute.

The number of output sentences may be bigger than on the input (e.g., using blocks such
as L<Treex::Block::W2A::ResegmentSentences>).

=head1 SYNOPSIS

  treex-socket-server.pl --port=8080 --src_zone=en:src --trg_zone=cs:tst --scenario=translate.scen
  
=head1 PARAMETERS

=over

=item port

The TCP port on which the server will start.

=item src_zone

The source zone (where source sentences will be stored). Use the following format: 
"language:selector" (where selector may be empty).

=item trg_zone

The target zone (from where the resulting sentences will be retrieved). Use the  
same format as for source zone.

=item scenario

The path to a scenario file.

=item detail

If set, more detailed JSON results will be returned on the output, including
tokenized input sentences and tokenized output sentences (obtained by concatenating 
forms of all a-tree nodes in the respective zones). 

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.