#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests=>1;

use Treex::Core;


my $scenario = Treex::Core::Scenario->new({from_string=>'Read::PEDT from=jmenosouboru'});

