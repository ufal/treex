#!/usr/bin/env perl
# Run this like so: `perl role.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/05/05 00:27:18

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
    unshift @INC, "$FindBin::Bin/lib";
}

use Test::More qw( no_plan );
BEGIN { use_ok( Treex::Tool::Prefixer ); }

my $prefix = 'test_';
my $init_args = { prefix => $prefix };

my $prefixer = Treex::Tool::Prefixer->new($init_args);

ok($prefixer->fingerprint, 'has fingerprint');
is($prefixer->_module, 'Treex::Tool::Prefixer', 'module name');
is_deeply($prefixer->init_args, $init_args, 'init args are valid');

done_testing();
