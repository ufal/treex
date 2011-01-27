#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 2;

use Treex::Core::Document;
use Treex::Core::Factory;

{
    my $filename = "tmp_empty.treex";
    my $doc = Treex::Core::Document->new;
    $doc->save($filename);
    my $doc_from_file = Treex::Core::Factory->createDocumentFromFile($filename);
    ok(defined $doc_from_file,'save and load empty treex file');
}

{
    my $filename = "tmp_just_text.treex";
    my $doc = Treex::Core::Document->new;
    my $attr_name = 'Sen text';
    my $attr_value = 'John loves Mary. Mary loves Detroit.';
    $doc->set_attr($attr_name, $attr_value);
    $doc->save($filename);
    my $doc_from_file = Treex::Core::Factory->createDocumentFromFile($filename);
    ok($doc_from_file->get_attr($attr_name) eq $attr_value, 'a document attribute properly stored with the document');
}





exit;
my $doc;
my $filename;

my $b1 = $doc->create_bundle;
$b1->set_attr('english_source_sentence','John loves Mary.');

my $ttree_root = $b1->create_tree('SenT');

my $child1 = $ttree_root->create_child;
my $child2 = $ttree_root->create_child;
my $child22 = $child2->create_child;
my $child3 = $child1->create_child;
$child3->set_parent($child2);

my $test_id = $child3->get_id;

my $ttree_root2 = $b1->create_tree('SarT');
my $ttree_root3 = $b1->create_tree('ScsT');

my $b2 = $doc->create_bundle;



$doc->save($filename);



# -----------------------

my $loaded_doc = Treex::Core::Factory->createDocumentFromFile($filename);
my ($first_bundle) = $loaded_doc->get_bundles;

my $loaded_root = $first_bundle->get_tree('SenT');

foreach my $tnode ($loaded_root,$loaded_root->get_descendants) {
    print "$tnode\t".$tnode->get_id."\n";
}

print "Referred node ".$loaded_doc->get_node_by_id($test_id)."\n";
