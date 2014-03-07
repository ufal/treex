#!/usr/bin/env perl
# Run this like so: `perl service_client.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/02/22 16:56:55

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 6;
BEGIN { use_ok (qw/Treex::Service::Client/) }

use Treex::Service::Server;
use Treex::Core::Scenario;
use IO::Socket::INET;
use File::Spec;
use File::Temp;
use Test::Files;
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

  my $res = $client->run_service('addprefix', {prefix => 'test_'}, ['a', 'b']);
  is_deeply($res, ['test_a', 'test_b'], 'Result from client is ok');

  # test in scenario
  $ENV{USE_SERVICES} = 0;
  $ENV{TREEX_SERVER_URL} = $server_url;
  my $fixture_file = File::Spec->catfile($FindBin::Bin, 'fixtures', 'test.txt');
  my $no_service_fh = File::Temp->new();
  my $no_service_file = $no_service_fh->filename;
  my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$fixture_file
W2A::EN::Segment
W2A::Tokenize
W2W::AddPrefix prefix='lala_'
Write::Treex to=$no_service_file
SCEN
  my $scenario = Treex::Core::Scenario->new(scenario_string => $scenario_string);
  $scenario->load_blocks;
  $scenario->run;

  #start using service
  $ENV{USE_SERVICES} = 1;
  my $service_fh = File::Temp->new();
  my $service_file = $service_fh->filename;
  $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$fixture_file
W2A::EN::Segment
W2A::Tokenize
W2W::AddPrefix prefix='lala_'
Write::Treex to=$service_file
SCEN
  $scenario = Treex::Core::Scenario->new(scenario_string => $scenario_string);
  $scenario->load_blocks;
  $scenario->run;

  compare_ok($no_service_file, $service_file,
             'Running scenario with service and without service yields same results');
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

kill(9, $pid) if $pid;
close $server if $server;

ok(!kill(0, $pid), 'Server is dead');

sub _port { IO::Socket::INET->new(PeerAddr => 'localhost', PeerPort => shift) }

#done_testing();
