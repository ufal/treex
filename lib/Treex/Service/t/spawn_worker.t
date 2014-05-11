#!/usr/bin/env perl
# Run this like so: `perl spawn_worker.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/04/30 13:31:57

use Carp::Always;
use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
    unshift @INC, "$FindBin::Bin/lib";
}
use File::Spec ();
use AnyEvent;
use Treex::Tool::Prefixer;

use Test::More qw( no_plan );

require TestTreexTool;

BEGIN { use_ok( Treex::Service::Pool ); }

my $prefix = 'test_';
my $init_args = { prefix => $prefix };

my $prefixer = Treex::Tool::Prefixer->new($init_args);

my $w = Treex::Service::Worker->new(
    router => $TestTreexTool::socket,
    fingerprint => $prefixer->fingerprint,
    module => 'Treex::Tool::Prefixer',
    init_args => $prefixer->init_args
);

my $cv = AE::cv;

$w->spawn();

$cv->recv;
$w->despawn;

waitpid $w->pid, 0;

TestTreexTool::close_connection();

done_testing();
