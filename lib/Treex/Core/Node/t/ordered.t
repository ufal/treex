#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Moose;
use Treex::Core::Document;

my $doc = new_ok('Treex::Core::Document');
my $bundle = $doc->create_bundle();
my $bzone = $bundle->create_zone('en');
my $t_root = $bzone->create_ttree();
does_ok($t_root, 'Treex::Core::Node::Ordered', 'T-root is ordered');

done_testing;
