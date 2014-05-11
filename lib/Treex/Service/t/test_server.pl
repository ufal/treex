#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
    unshift @INC, "$FindBin::Bin/lib";
}
use AnyEvent::Fork::Early;
use Treex::Core::Config;
use Treex::Service::Router;

my $url = $ARGV[0] || Treex::Core::Config->treex_server_url;
Treex::Service::Router::run_router($url);

print STDERR "Server has exited gracefully\n";
