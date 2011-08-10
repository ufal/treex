#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;
BEGIN { require_ok('Treex::Block::Read::BaseReader') }

my $reader = Treex::Block::Read::BaseReader->new( from => '-', file_stem => 'test' );
isa_ok( $reader, 'Treex::Block::Read::BaseReader' );

stderr_like(
    sub {
        eval { $reader->next_document() };
    },
    qr/method next_document must be overriden in/,
    'subroutine next_document has to fail'
);

cmp_ok( $reader->number_of_documents(), '==', 1, 'There should be exactly one document' );

$reader->next_filename();

is( $reader->current_filename(), '-', 'Current file is STDIN(-)' );

done_testing();
