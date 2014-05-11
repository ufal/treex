#!/usr/bin/env perl
# Run this like so: `perl role.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/05/05 00:27:18

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/lib";
}
$ENV{USE_SERVICES} = 0;
use Test::More;
BEGIN { use_ok( Treex::Tool::Prefixer ); }

my $prefix = 'test_';
my $init_args = { prefix => $prefix };

my $prefixer = Treex::Tool::Prefixer->new($init_args);

can_ok('Treex::Tool::Prefixer',
       qw(impl_module _client use_service fingerprint init_args init_timeout process_timeout));

can_ok('Treex::Tool::Prefixer', qw(initialize process));

ok(!$prefixer->use_service, "doesn't use service");
ok($prefixer->fingerprint, 'has fingerprint');
is($prefixer->impl_module, 'Treex::Tool::Prefixer', 'module name');
is_deeply($prefixer->init_args, $init_args, 'init args are valid');

$prefixer->initialize();
my $res = $prefixer->process([qw(a b c)]);
my $ex_res = [qw(test_a test_b test_c)];

is_deeply($res, $ex_res, 'result');

$ENV{USE_SERVICES} = 1;
$ENV{TREEX_SERVER_URL} = 'ipc://role-test';

$init_args = { %$init_args, process_timeout => 1, init_timeout => 1 };

my $p1 = Treex::Tool::Prefixer->new($init_args);
ok($p1->use_service, "use service");

$p1->initialize();
is($prefixer->fingerprint, $p1->fingerprint, 'ignore roles attributes');
ok(!$p1->use_service, "doesn't use service");

$prefixer = Treex::Tool::Prefixer->new($init_args);
ok($prefixer->use_service, "use service");
$res = $prefixer->process([qw(a b c)]);
ok(!$prefixer->use_service, "doesn't use service");
is_deeply($res, $ex_res, 'fallback worked');

done_testing();
