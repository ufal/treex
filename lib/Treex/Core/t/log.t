#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;

BEGIN { use_ok('Treex::Core::Log') }

my @values = qw(ALL DEBUG INFO WARN FATAL);

foreach my $level (@values) {
    ok( eval {
            log_set_error_level($level);
            1;
        },
        "Can set errorlevel $level",
    ) or diag($@);

}

log_set_error_level('ALL');

Treex::Core::Log::add_hook('FATAL',sub {print 'hook1'});

stdout_is ( sub { eval { log_fatal ('dummy message') } }, 'hook1',
            'hook for log_fatal executed correctly, prior to reporting fatal message');

Treex::Core::Log::add_hook('FATAL',sub {print 'hook2'});
stdout_is ( sub { eval { log_fatal ('dummy message') } }, 'hook1hook2',
            'hooks executed in correct order');

done_testing();

