#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Core::Run q(treex);

use Test::More tests => 1;
use Test::Output;

foreach my $i (1..3) {
    my $doc = Treex::Core::Document->new();
    $doc->save("dummy$i.treex");
}

my $cmdline_arguments = "-q Util::Eval document='print 1' -g 'dummy?.treex'";
stdout_is( sub { treex $cmdline_arguments },'111',"checking Util::Eval: treex $cmdline_arguments");


unlink glob "dummy*";
