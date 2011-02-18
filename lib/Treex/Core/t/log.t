#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
BEGIN { use_ok('Treex::Core::Log') }

my @values = qw(ALL DEBUG INFO WARN FATAL);

foreach (@values) {
    ok( eval {
            log_set_error_level($_);
            1;
        },
        "Can set errorlevel $_",
    );

}

done_testing();

