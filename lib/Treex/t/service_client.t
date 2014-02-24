#!/usr/bin/env perl
# Run this like so: `perl service_client.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/02/22 16:56:55

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;
BEGIN { use_ok (qw/Treex::Service::Client/) }

use Treex::Service::Server;
use IO::Socket::INET;
use Mojo::IOLoop;
my $port  = Mojo::IOLoop->generate_port;
my $server_url = "http://localhost:$port";

my $treex_server_script = "$FindBin::Bin/test_server.pl";
my ($pid, $server);
eval {
  $pid = open($server, '-|', $treex_server_script, 'daemon', '-l', $server_url)
    || die "Can't start server";
  print STDERR "server pid: $pid on url: $server_url\n";
  sleep 1 while !_port($port);

  my $client = Treex::Service::Client->new(server_url => $server_url);

  ok($client->service_available('addprefix'), 'Service AddPrefix is available');

  my $res = $client->run_service('addprefix', {prefix => 'test_'}, ['a']);
  is_deeply($res, ['test_a'], 'Result from client is ok');
};

kill(9, $pid) if $pid;
close $server if $server;

ok(!kill(0, $pid), 'Server is dead');


sub _port { IO::Socket::INET->new(PeerAddr => 'localhost', PeerPort => shift) }

done_testing();


