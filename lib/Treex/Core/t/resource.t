#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;

BEGIN { require_ok('Treex::Core::Resource') }

SKIP:
{
    skip "May fail when not online", 1 unless ($ENV{AUTHOR_TESTING});
    my $file = Treex::Core::Resource::require_file_from_share('tred/README');

    ok( -e $file, 'file from resource exists' );
}
done_testing();

