#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
BEGIN { unshift @INC, "$FindBin::Bin/../lib" }

$ENV{TREEX_SERVER_CACHE_SIZE} = 1;

# Start command line interface for application
require Mojolicious::Commands;
Mojolicious::Commands->start_app('Treex::Service::Server');
