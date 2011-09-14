#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use_ok('Treex::Block::Read::BaseAlignedTextReader');

my $reader = Treex::Block::Read::BaseAlignedTextReader->new();

my $texts_ref = $reader->next_document_texts();
TODO: {
    local $TODO = 'test not ready yet';
    ok( $texts_ref, 'Can load texts' );
}

my $reader2 = Treex::Block::Read::BaseAlignedTextReader->new( lines_per_doc => 10 );
isa_ok( $reader2, 'Treex::Block::Read::BaseAlignedTextReader' );

#ok( !$reader->is_one_doc_per_file(), 'When lines per doc, there is not one doc per file' );

TODO: {
    local $TODO = 'option lines_per_document not implemented yet';
    my $texts_ref = eval {
        $reader2->next_document_texts();
    };
    ok( $texts_ref, 'Can load texts' );

}
__DATA__

