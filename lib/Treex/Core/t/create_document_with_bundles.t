#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

my $doc = Treex::Core::Document->new;
$doc->set_attr('Sen text','John loves Mary.');

my $b1 = $doc->create_bundle;
$b1->set_attr('Sen sentence','John loves Mary.');

my $b2 = $doc->create_bundle;
$b2->set_attr('Sen sentence','Mary loves John');

$doc->save('with_bundles.tmt');
