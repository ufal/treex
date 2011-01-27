#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

my $doc = Treex::Core::Document->new;

my $b1 = $doc->create_bundle;

$b1->create_tree('SenT');
$b1->create_tree('SenA');
$b1->create_tree('SarT');

$b1->set_attr('Sen sentence','John loves Mary');

$doc->save('with_tree.tmt');
