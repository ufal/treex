#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Block::Read::CdtTag;
use File::Basename;
my $my_dir = dirname($0);

my $reader = Treex::Block::Read::CdtTag->new(
    from => join ',', map {"$my_dir/$_"} qw(cdt-test-0005-da.tag cdt-test-0005-es-lotte.tag cdt-test-0005-it-lisa.tag),
);

my @documents;
my $new_document;
while ($new_document = $reader->next_document) {
    push @documents, $new_document;
}


is(scalar(@documents), 3, q(All test tag files loaded));

done_testing();


END {
# delete temporary files
}
