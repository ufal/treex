#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Output;
use Treex::Core::Run;

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.txt b.txt)),
    'Read::Text',
);

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.treex b.treex)),
    'Read::Treex'
);

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.treex.gz b.treex.gz)),
    'Read::Treex'
);
TODO: {
    local $TODO = 'Cannot mix gzipped and plain files yet';
    is(
        eval{ Treex::Core::Run->_get_reader_name_for(qw(a.treex.gz b.treex))},
        'Read::Treex'
    );
}

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.txt b.treex))}
    },
    qr/must have the same extension/
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a b))}
    },
    qr/must have extensions/
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.aaa b.aaa))}
    },
    qr/(no DocumentReader implemented|must have extensions)/
);
