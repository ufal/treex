#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;
use File::Slurp;
use Treex::Core::Config;
use Treex::Core::Document;
use Treex::Block::W2A::SegmentOnNewlines;
my $content = <<'EOF';
First sentence.
Second sentence.
EOF

my $content_with_empty = <<'EOF';
First sentence.
Second sentence.

After empty.
EOF

my $TMP_DIR = Treex::Core::Config::tmp_dir();

my $plain_file  = "$TMP_DIR/plain.txt";
my $spaced_file = "$TMP_DIR/spaced.txt";

write_file( $plain_file,  $content );
write_file( $spaced_file, $content_with_empty );

my $doc     = Treex::Core::Document->new();
my $doczone = $doc->create_zone('en');
$doczone->set_text($content);
my $segment = Treex::Block::W2A::SegmentOnNewlines->new( language => 'en' );
$segment->process_document($doc);
cmp_ok( scalar $doc->get_bundles(), '==', 2, 'There are two sentences in two line text' );

my $doc2     = Treex::Core::Document->new();
my $doczone2 = $doc2->create_zone('en');
$doczone2->set_text($content_with_empty);
stderr_like(
    sub {
        eval { $segment->process_document($doc2) };
    },
    qr/contains empty sentences/,
    'Segmenting text with empty lines should crash'
);
my $allow_segmenter = Treex::Block::W2A::SegmentOnNewlines->new( language => 'en', allow_empty_sentences => 1 );
$allow_segmenter->process_document($doc2);
cmp_ok( scalar $doc2->get_bundles(), '==', 4, 'There are four sentences in four line text when allow_empty_senteces set' );

my $doc3     = Treex::Core::Document->new();
my $doczone3 = $doc3->create_zone('en');
$doczone3->set_text($content_with_empty);
my $delete_segmenter = Treex::Block::W2A::SegmentOnNewlines->new( language => 'en', delete_empty_sentences => 1 );
$delete_segmenter->process_document($doc3);
cmp_ok( scalar $doc3->get_bundles(), '==', 3, 'There are three sentences in four line text when delete_empty_senteces set' );

done_testing();

END {
    unlink $plain_file;
    unlink $spaced_file;
}
