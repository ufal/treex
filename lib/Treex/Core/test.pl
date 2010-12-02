#!/usr/bin/env perl

use strict;
use warnings;

use Treex::PML;

use Treex::Core::Factory;

Treex::Core::Factory->make_default();

my $doc = Treex::Core::Factory->createDocumentFromFile($ARGV[0]);

print ref($doc),"\n";

for my $bundle ($doc->get_bundles) {
    print ref($bundle),"\t",$bundle->get_attr('id'),"  in document:".$bundle->get_document()."\n";
    my $a_root = $bundle->get_tree('SeoA');
    print join " ",map {$_->get_attr('id')} $a_root->get_descendants;
    print "\n";
}

print "Testing: get_node_by_id\t".$doc->get_node_by_id('SeoA-s16-rootx40')."\n";
