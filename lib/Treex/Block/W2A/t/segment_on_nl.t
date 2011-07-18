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



#my $doc = Treex::Core::Document->new(text=>$content);
#$doc->set_text=$content;
#$doc->create_zone('en');
#my $segment = Treex::Block::W2A::SegmentOnNewlines->new();
#$segment->process_document($doc);
#
#cmp_ok(scalar $doc->get_bundles(),'==',2);



done_testing();

END {
    unlink $plain_file;
    unlink $spaced_file;
}
