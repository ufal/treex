#!/usr/bin/env perl
use strict;
use warnings;

$ENV{'TREEX_MAKE_BACKREFS'} = 1;
use Treex::Core;
use Treex::PML::Factory;
my $factory = Treex::PML::Factory->new();

use Test::More;

my $doc    = Treex::Core::Document->new;
my $bundle = $doc->create_bundle;
my $zone   = $bundle->create_zone('en');

my $ttree = $zone->create_ttree;
my $atree = $zone->create_atree;

my $referenced = $atree->create_child( { ord => 0 } );

my $attr_name  = 'a/lex.rf';
my $attr_value = $referenced->id;

my $referring = $ttree->create_child( { $attr_name => $attr_value } );

## TODO: more test before save

my $filename = 'test.treex';
$doc->save($filename);

my $loaded_doc = Treex::Core::Document->new( { 'filename' => $filename } );
my ($loaded_bundle) = $loaded_doc->get_bundles;
my ($loaded_tnode)  = $loaded_bundle->get_zone('en')->get_ttree->get_children;
my ($loaded_anode)  = $loaded_bundle->get_zone('en')->get_atree->get_children;
is(
    $loaded_tnode->get_attr($attr_name), $attr_value,
    "Storing complex refference"
);
my $refs     = $loaded_tnode->refs;
my $backrefs = $loaded_anode->backrefs;
my $tnode_id = $loaded_tnode->id;
ok( ( $backrefs and $backrefs->{$attr_name} ), "Backrefs for $attr_name is defined on anode" );
is( $backrefs->{$attr_name}->{$tnode_id}->id, $tnode_id, "Backref to $tnode_id is set correctly" );

unlink $filename;
done_testing();
