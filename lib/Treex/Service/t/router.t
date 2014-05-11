#!/usr/bin/env perl
# Run this like so: `perl router.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/05/09 18:23:13

use warnings;
use strict;

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}

use Test::More;
BEGIN { use_ok( 'Treex::Service::Router' ); }
BEGIN { use_ok( 'Treex::Service::Client' ); }

use AnyEvent;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_ROUTER ZMQ_DEALER);
use Treex::Service::MDP qw(:all);
use Storable qw(freeze thaw);
use Treex::Tool::Prefixer;

my $test_socket = "ipc://treex-test-router-$$";
$ENV{USE_SERVICES} = 0;
$ENV{TREEX_SERVER_URL} = $test_socket;

my $router = Treex::Service::Router->new(endpoint => $test_socket);
isa_ok($router, 'Treex::Service::Router');
$router->listen;

my $context = $router->context;

my $client = Treex::Service::Client->new(endpoint => $test_socket);

my $p = Treex::Tool::Prefixer->new(prefix => 'p-');

my $cv = AE::cv;
my $input = [qw(a b c d)];
my $res_ex = [qw(p-a p-b p-c p-d)];

my $res = $client->send($p);     # send just init
is($res, 1, 'init ok');

is($router->pool->workers_count, 1, 'has worker');

$res = $client->send($p, [$input]); # process
is_deeply($res->[0], $res_ex, 'result from client');

$ENV{USE_SERVICES} = 1;

$p = Treex::Tool::Prefixer->new(prefix => 'p-');
is($p->use_service, 1, 'services enabled');
$p->initialize;
is($p->use_service, 1, 'services still enabled');

my $a = $p->process($input);
is($p->use_service, 1, 'services still enabled');
is_deeply($a, $res_ex, 'result from prefixer');

done_testing();
