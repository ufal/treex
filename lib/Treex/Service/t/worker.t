#!/usr/bin/env perl
# Run this like so: `perl worker.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/04/30 13:31:57

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}

use Test::More;

$ENV{USE_SERVICES} = 0;

BEGIN { use_ok( Treex::Service::Worker ); }

use File::Spec ();
use AnyEvent;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_ROUTER ZMQ_DEALER);
use Treex::Service::MDP qw(:all);
use Storable qw(freeze thaw);
use Treex::Tool::Prefixer;

my $prefix = 'test_';
my $init_args = { prefix => $prefix };
my $test_socket = 'ipc://treex-worker-test';

my $prefixer = Treex::Tool::Prefixer->new($init_args);

my $w = Treex::Service::Worker->new(
    router => $test_socket,
    fingerprint => $prefixer->fingerprint,
    module => 'Treex::Tool::Prefixer',
    init_args => $prefixer->init_args
)->initialize;

my $context = $w->context;      # Reuse context
my $router = $context->socket(ZMQ_ROUTER);
$router->set_linger(0);
$router->bind($test_socket);

# Init ok
{
    ok($w->instance, 'value ok');
    isa_ok($w->instance, 'Treex::Tool::Prefixer', 'class ok');
    isnt($w->instance, $prefixer, 'different instances');
    is($w->instance->fingerprint, $prefixer->fingerprint, 'prints ok');
    is($w->fingerprint, $prefixer->fingerprint, 'prints ok');
}
my $connected;
my $identity;

$w->once(connected => sub { $connected = 1 });
$w->reconnect_router;
ok($connected, 'connected');

{
    #diag 'ready';
    $w->send_ready;
    my @msg = $router->recv_multipart();

    #diag join ',', @msg;

    ok($identity = shift @msg, 'identity');
    $w->set_identity($identity);
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_READY, 'ready message');
    is(shift @msg, $w->fingerprint, 'fingerprint');
    ok(@msg == 0, 'and nothing more');
}

{
    #diag 'heartbeat';
    $w->send_heartbeat;

    my @msg = $router->recv_multipart();

    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_HEARTBEAT, 'heartbeat message');
    ok(@msg == 0, 'and nothing more');
}

{
    #diag 'disconnect';
    $w->send_disconnect;

    my @msg = $router->recv_multipart();

    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_DISCONNECT, 'disconnect message');
    ok(@msg == 0, 'and nothing more');
}

my @test_input = ([qw(a b c d)]);
my @result = $prefixer->process(@test_input);

my $client = $context->socket(ZMQ_DEALER);
$client->set_linger(0);
$client->connect($test_socket);
my $reply_to;

{
    $client->send_multipart(['', C_CLIENT, freeze(\@test_input)]);
    my @msg = $router->recv_multipart();

    ok($reply_to = shift @msg, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, C_CLIENT, 'worker frame');
    my $input = thaw(shift @msg);
    ok($input && ref $input, 'has input');
    is_deeply($input, \@test_input, 'and input is valid');
    ok(@msg == 0, 'and has nothing more');

    $router->send_multipart([$w->identity, '',
                             W_WORKER, W_REQUEST, $reply_to, '',
                             freeze($input)]);

    @msg = $w->socket->recv_multipart();

    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_REQUEST, 'request command frame');
    is(shift @msg, $reply_to, 'reply match to client');
    is(shift @msg, '', 'empty frame');
    $w->send_reply($reply_to, @{thaw(shift @msg)});
    ok(@msg = 0, 'has nothing more');

    @msg = $router->recv_multipart();
    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_REPLY, 'reply command');
    is(shift @msg, $reply_to, 'client identity');
    is(shift @msg, '', 'empty frame');
    my $res = thaw(shift @msg);
    ok($res && ref $res, 'has result');
    is_deeply($res, \@result, 'valid result');
}

$w = Treex::Service::Worker->new(
    router => $test_socket,
    fingerprint => $prefixer->fingerprint,
    module => 'Treex::Tool::Prefixer',
    init_args => $prefixer->init_args
);

my $spawned;
{
    my $cv = AE::cv;
    $w->on(spawn => sub { $spawned = $_[1]; $cv->send });
    $w->spawn();
    $cv->recv;
}

is($spawned, $w->pid, 'pid set');
ok($w->running, 'running set');
ok(kill(0, $spawned), 'really running');

{
    my @msg = $router->recv_multipart();

    ok($identity = shift @msg, 'identity');
    $w->set_identity($identity);
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_READY, 'ready message');
    is(shift @msg, $w->fingerprint, 'fingerprint');
    ok(@msg == 0, 'and nothing more');
}

# wait for heartbeat
{
    my @msg = $router->recv_multipart();
    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_HEARTBEAT, 'heartbeat message');
    ok(@msg == 0, 'and nothing more');
}

# bounce a request
$router->send_multipart([$w->identity, '',
                         W_WORKER, W_REQUEST, $reply_to, '',
                         freeze(\@test_input)]);

{
    my @msg = $router->recv_multipart();
    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_REPLY, 'reply command');
    is(shift @msg, $reply_to, 'client identity');
    is(shift @msg, '', 'empty frame');
    my $res = thaw(shift @msg);
    ok($res && ref $res, 'has result');
    is_deeply($res, \@result, 'valid result');
}

$w->despawn();

ok(!$w->running, 'running unset');
ok($w->quit, 'quit is set');

# recv disconnect
{
    my @msg = $router->recv_multipart();

    is(shift @msg, $identity, 'identity');
    is(shift @msg, '', 'empty frame');
    is(shift @msg, W_WORKER, 'worker frame');
    is(shift @msg, W_DISCONNECT, 'disconnect message');
    ok(@msg == 0, 'and nothing more');
}

my $alive; my $timeout = 5;

while ($alive = kill(0, $w->pid) && $timeout > 0) {
    sleep 1;
    $timeout -= 1;
}

ok(!$alive, 'not running anymore');

$w = Treex::Service::Worker->new(
    router => $test_socket,
    fingerprint => $prefixer->fingerprint,
    module => 'Treex::Tool::Prefixer',
    init_args => $prefixer->init_args
);

{
    my $cv = AE::cv;
    $w->on(spawn => sub { $spawned = $_[1]; $cv->send });
    $w->spawn();
    $cv->recv;
}
is($spawned, $w->pid, 'pid set');

$w->despawn(1);

$timeout = 5;
while ($alive = kill(0, $w->pid) && $timeout > 0) {
    sleep 1;
    $timeout -= 1;
}

ok(!$alive, 'killed, not running anymore');

done_testing();
