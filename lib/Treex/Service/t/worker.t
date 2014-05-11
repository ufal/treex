#!/usr/bin/env perl
# Run this like so: `perl worker.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/04/30 13:31:57

use Carp::Always;
use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}
use File::Spec ();
use AnyEvent;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_ROUTER ZMQ_DEALER);
use Treex::Service::MDP qw(:all);
use Storable qw(freeze thaw);
use Treex::Tool::Prefixer;

use Test::More;

BEGIN { use_ok( Treex::Service::Worker ); }

my $prefix = 'test_';
my $init_args = { prefix => $prefix };
my $test_socket = 'inproc://test';

my $prefixer = Treex::Tool::Prefixer->new($init_args);

my $cv = AE::cv;
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

{
    $client->send_multipart(['', C_CLIENT, freeze(\@test_input)]);
    my @msg = $router->recv_multipart();

    ok(my $reply_to = shift @msg, 'identity');
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

done_testing();
