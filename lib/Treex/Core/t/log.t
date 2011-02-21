#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
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

done_testing();

