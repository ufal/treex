#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use Treex::Core::Document;
use Treex::Block::W2A::Tokenize;

my $sentence = 'http://example.com costs $10.5  and forty-two C++ programmers.';
my $expected = 'http://example.com costs $ 10.5 and forty-two C++ programmers .';
my $block    = new_ok('Treex::Block::W2A::Tokenize');
my $got      = $block->tokenize_sentence($sentence);
is($got, $expected, "Tokenizing '$sentence'");

$sentence   = '. . . tricky one.';
$expected   = 'ord=1|form=...|no_space_after=0 ord=2|form=tricky|no_space_after=0 ord=3|form=one|no_space_after=1 ord=4|form=.|no_space_after=0';
my $doc     = Treex::Core::Document->new();
my $bundle  = $doc->create_bundle();
my $zone    = $bundle->create_zone('en');
$zone->set_sentence($sentence);
$block->process_document($doc);
my $atree = $zone->get_atree();
$got = join ' ', map {'ord='.$_->ord.'|form='.$_->form.'|no_space_after='.$_->no_space_after} $atree->get_descendants({ordered=>1});

is($got, $expected, "Tokenizing via process_document '$sentence'");