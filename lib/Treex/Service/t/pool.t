#!/usr/bin/env perl
# Run this like so: `perl pool.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/05/09 18:27:02

use warnings;
use strict;

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}

$ENV{USE_SERVICES} = 0;
use Test::More;
BEGIN { use_ok( 'Treex::Service::Pool' ); }

use AnyEvent;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_ROUTER);
use List::MoreUtils qw(all);

use Treex::Service::MDP qw(:all);
use Treex::Service::Worker;
use Treex::Tool::Prefixer;

my $test_socket = 'ipc://treex-pool-test';
my $context = ZMQ::FFI->new;
my $router = $context->socket(ZMQ_ROUTER);
$router->set_linger(0);
$router->bind($test_socket);

my $pool = new_ok('Treex::Service::Pool' => [cache_size => 4]);

is($pool->cache_size, 4, 'cache size');

my @prefixers = map {Treex::Tool::Prefixer->new({prefix => "p$_-"})} 1..10;
my ($p1, $p2, $p3, $p4, $p5, $p6, $p7, $p8, $p9, $p10) = @prefixers;

is(scalar(@prefixers), 10, 'prefixers');

# check fingerprints
my %prints = map { $_->fingerprint => 1 } @prefixers;
is(scalar(keys %prints), 10, 'have prints');

my @workers = map {
    Treex::Service::Worker->new(
        router => $test_socket,
        fingerprint => $_->fingerprint,
        module => 'Treex::Tool::Prefixer',
        init_args => $_->init_args
    )} @prefixers;
my ($w1, $w2, $w3, $w4, $w5, $w6, $w7, $w8, $w9, $w10) = @workers;

is($pool->workers_count, 0, 'no workers');
$pool->set_worker($w1);
$pool->set_worker($w2);
$pool->set_worker($w3);
is($pool->workers_count, 3, '3 workers');

my $w = $pool->get_worker($w1->fingerprint);
is($w, $w1, 'get w1 worker');
$w = $pool->get_worker($w10->fingerprint);
is($w, undef, 'fail to get worker');

$pool->set_worker($w4);
$pool->set_worker($w5);
is($pool->workers_count, 4, '4 workers');
$w = $pool->get_worker($w1->fingerprint);
is($w, $w1, 'get w1 worker');
$w = $pool->get_worker($w2->fingerprint);
is($w, undef, 'w2 worker is gone');

is_deeply({map {$_->fingerprint => $_} $pool->all_workers},
          {
              map {$_->fingerprint => $_} ($w1, $w3, $w4, $w5)},
          'check workers');

$w = $pool->remove_worker($w1->fingerprint);
is($w, $w1, 'remove w1 worker');
is($pool->workers_count, 3, 'count decrease');
$w = $pool->remove_worker($w2->fingerprint);
is($w, undef, 'removed non existing worker');
is($pool->workers_count, 3, 'count stayed the same');
$w = $pool->get_worker($w1->fingerprint);
is($w, undef, 'getting w1 worker failed');

$pool->clear;
is($pool->workers_count, 0, 'clear pool');

my $spawned = 0;
my $counter = 0;
my $cv = AE::cv;

my @running = map {
    my $ww = $pool->start_worker({
        router => $test_socket,
        fingerprint => $_->fingerprint,
        module => 'Treex::Tool::Prefixer',
        init_args => $_->init_args
    });
    $ww->on(spawn => sub { $spawned += 1 }); $ww
} ($p1, $p2, $p3, $p4);

{
    my $fd = $router->get_fd;
    my $io;
    $io = AE::io $fd, 0, sub {
        while ( $router->has_pollin ) {
            my @msg = $router->recv_multipart();

            next unless $msg[3] eq W_READY; # ignore everything except ready
            $cv->send if ++$counter == scalar(@running)
        }
    };
    $cv->recv;
    undef $io;
}
is($pool->workers_count, 4, 'count');
is($spawned, scalar(@running), 'all workers spawned');
is($counter, scalar(@running), 'all workers ready');

isa_ok($running[0], 'Treex::Service::Worker');

ok((all {$_->running} @running), 'running');
ok((all {$_->pid} @running), 'have pids');

my $w1_pid = $running[0]->pid;

$cv = AE::cv;
$pool->start_worker({
    router => $test_socket,
    fingerprint => $p5->fingerprint,
    module => 'Treex::Tool::Prefixer',
    init_args => $p5->init_args
})->on(spawn => sub { $cv->send });

$cv->recv;

$w = $pool->get_worker($p1->fingerprint);
is($w, undef, 'w1 worker autoremoved');
$w = shift @running; # destroy reference
$w = undef;

my $alive; my $timeout = 5;

while ($alive = kill(0, $w1_pid) && $timeout > 0) {
    sleep 1;
    $timeout -= 1;
}
ok(!$alive, 'w1 not running anymore');

$pool->cache_size(2);
is($pool->workers_count, 2, 'cache decrease');
$w = shift @running;            # destroy reference
my $w2_pid = $w->pid;
$w = undef;

while ($alive = kill(0, $w2_pid) && $timeout > 0) {
    sleep 1;
    $timeout -= 1;
}
ok(!$alive, 'w2 not running anymore');

$w = shift @running;
my $w3_pid = $w->pid;
ok(!$pool->worker_exists($w->fingerprint), 'w3 not exists');
ok(kill(0, $w3_pid), 'but still running');

done_testing();
