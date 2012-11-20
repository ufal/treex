#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Block::Read::WordAlignmentXML;
use File::Basename;
my $my_dir = dirname($0);

my $reader = Treex::Block::Read::WordAlignmentXML->new(
    from => "$my_dir/word_alignment_xml_sample.wa",
);

my $document = $reader->next_document;
my @en_nodes = map {$_->get_zone('en')->get_atree->get_descendants} $document->get_bundles;

is(scalar(@en_nodes), 41, q(Correct number of English tokens read from the wa-file.));

done_testing();

END {
# delete temporary files
}
