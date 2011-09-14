#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Treex::Block::Read::BaseAlignedReader;
use Test::Output;
#require next_document overriden


my $reader = new_ok('Treex::Block::Read::BaseAlignedReader');

stderr_like(sub{
    eval {
       $reader->next_document(); 
    }
}, qr/next_document must be overriden/, q(require next_document overriden)  );



TODO: {
    local $TODO = 'Need tests on (next|current)_filenames a spol.';

    fail( 'Write some tests' );
}

