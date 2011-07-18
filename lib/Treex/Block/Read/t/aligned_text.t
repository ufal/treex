#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;

use Treex::Block::Read::AlignedSentences;
use File::Slurp;
use Treex::Core::Config;

my $TMP_DIR = Treex::Core::Config::tmp_dir();

my $en_content = <<'EOF';
Hi.
How are you?
EOF

my $cs_content = <<'EOF';
Ahoj.
Jak se máš?
EOF

my $cs_content2 = <<'EOF';
Ahoj.
Jak se máš?
Tohle je tu navíc!
EOF

my $en_file  = "$TMP_DIR/en1.txt";
my $cs_file  = "$TMP_DIR/cs1.txt";
my $cs2_file = "$TMP_DIR/cs2.txt";
write_file( $en_file,  $en_content );
write_file( $cs_file,  $cs_content );
write_file( $cs2_file, $cs_content2 );

#Can read aligned texts
my $reader = Treex::Block::Read::AlignedSentences->new( en => $en_file, cs_ref => $cs_file );

my $doc = $reader->next_document();
isa_ok( $doc, 'Treex::Core::Document', 'New document is valid Treex document' );

#What is read is same as in file
#note(explain($doc));
my @bundles = $doc->get_bundles();
cmp_ok(scalar @bundles, '==', 2, '2 bundles were loaded');

#Fail if texts have different size

my $another_reader = Treex::Block::Read::AlignedSentences->new( en=> $en_file, cs_ref=>$cs2_file);
stderr_like(sub {eval { $another_reader->next_document() } } , qr/Different number of lines in aligned documents/, 'Loading of files with different number of lines should fail');

done_testing();

END {
    unlink $en_file;
    unlink $cs_file;
    unlink $cs2_file;
}
