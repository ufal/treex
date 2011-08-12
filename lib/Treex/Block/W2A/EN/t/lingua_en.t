#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;                      

use Treex::Block::W2A::EN::TagLinguaEn;
use Treex::Core::Document;

my $block = new_ok('Treex::Block::W2A::EN::TagLinguaEn' => [
    qw(language en)
]);


my $doc = Treex::Core::Document->new();
my $bundle = $doc->create_bundle();
my $zone = $bundle->create_zone('en');
$zone->set_sentence('How are you?');
$block->process_zone($zone);
ok($zone->has_atree());
done_testing();
