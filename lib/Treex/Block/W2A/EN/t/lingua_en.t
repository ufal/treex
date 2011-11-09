#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Slurp 9999;
use Readonly;
Readonly::Scalar my $found_another_substitution => 0;

eval {
    require Lingua::EN::Tagger;
    1;
} or plan skip_all=>'Cannot load Lingua::EN::Tagger';



use_ok('Treex::Block::W2A::EN::TagLinguaEn');
use Treex::Core::Document;
use Treex::Core::Log;
my $block = new_ok(
    'Treex::Block::W2A::EN::TagLinguaEn' => [
        qw(language en)
    ],
    "Created block"
);

my $doc      = Treex::Core::Document->new();
my $bundle   = $doc->create_bundle();
my $zone     = $bundle->create_zone('en');
my $sentence = q(How are you?);
my $expected_tags = 'WRB VBP PRP .';
note("Using testing sentence: $sentence");
$zone->set_sentence($sentence);
$block->process_zone($zone);
ok( $zone->has_atree(), q(There's a_tree in result) );
my @children = $zone->get_atree()->get_children();
cmp_ok( scalar @children, '==', 4, q(There are 4 tokens in the a_tree) );
my $you_node = $children[2];
ok( $you_node->no_space_after(), q('you' has no_space_after) );
my $qmark_node = $children[3];
ok( !$qmark_node->no_space_after(), q('?' has NOT no_space_after) );

my $tags = join ' ', map {$_->tag} @children;
is($tags, $expected_tags, 'Correct tags assigned');

my $line = <DATA>;

my $doc2      = Treex::Core::Document->new();
my $bundle2   = $doc2->create_bundle();
my $zone2     = $bundle2->create_zone('en');
my $sentence2 = $line;
$zone2->set_sentence($sentence2);
my $result = eval{
    $block->process_zone($zone2);
    1;
};
TODO: {
    local $TODO = q(This wasn't repaired yet) if $found_another_substitution;
    ok ($result, q(Succesfully tagged another sentence));
}
#ok ($zone2->has_atree(), q(There's a_tree in another result) );

done_testing();
__DATA__
"There is a strong climate of fear and all eyes are on developments in Greece," said Marc Ostwald, fixed-income research strategist at Monument Securities. "There is the possibility of a nasty shock before things get better."
