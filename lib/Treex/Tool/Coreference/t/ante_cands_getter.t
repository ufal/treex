#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Treex::Block::Read::Treex;

BEGIN {
    use_ok('Treex::Tool::Coreference::NounAnteCandsGetter');
    use_ok('Treex::Tool::Coreference::ContentCandsGetter');
    use_ok('Treex::Tool::Context::Sentences');
}

my $filename = '/net/data/czeng10-public-release/data.treex-format/00train/f00001.treex.gz';
my $reader = Treex::Block::Read::Treex->new(language => 'en', from => $filename);
my $doc = $reader->next_document();

# picking a random node
my $id = 't_tree-cs-fiction-b5-00train-f00001-s58-n2898';
my $node = $doc->get_node_by_id($id);

my $noun_ante_getter = new_ok('Treex::Tool::Coreference::NounAnteCandsGetter',
[{
    prev_sents_num => 2,
    anaphor_as_candidate => 1,
    cands_within_czeng_blocks => 1,
}]);

my $cands = $noun_ante_getter->get_candidates($node);
is(scalar @$cands, 19, 'previous context noun candidates ok');

my $content_ante_getter = new_ok('Treex::Tool::Coreference::ContentCandsGetter',
[{
    prev_sents_num => 2,
    anaphor_as_candidate => 0,
    cands_within_czeng_blocks => 1,
}]);

$cands = $content_ante_getter->get_candidates($node);
is(scalar @$cands, 27, 'previous context content-word candidates ok');

done_testing();
