#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Output;
use Treex::Core::Run;

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.txt b.txt)),
    'Read::Text',
    'reader for *.txt'
);

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.txt.gz b.txt.gz)),
    'Read::Text',
    'reader for *.txt.gz'
);

is(
    eval{ Treex::Core::Run->_get_reader_name_for(qw(a.txt.gz b.txt))},
    'Read::Text',
    'reader for *.txt and *.txt.gz'
);


is(
    Treex::Core::Run->_get_reader_name_for(qw(a.treex b.treex)),
    'Read::Treex',
    'reader for *.treex'
);

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.treex.gz b.treex.gz)),
    'Read::Treex',
    'reader for *.treex.gz'
);

is(
    Treex::Core::Run->_get_reader_name_for(qw(a.streex b.streex)),
    'Read::Treex',
    'reader for *.streex'
);

is(
    eval{ Treex::Core::Run->_get_reader_name_for(qw(a.treex.gz b.treex))},
    'Read::Treex',
    'reader for *.treex and *.treex.gz'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.txt b.treex))}
    },
    qr/must have the same extension/,
    'mixing *.txt and *.treex'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a b))}
    },
    qr/must have extensions/,
    'files without extension'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.aaa b.aaa))}
    },
    qr/(no DocumentReader implemented|must have extensions)/,
    'files with unknown extension'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.aaa b.txt))}
    },
    qr/(no DocumentReader implemented|must have extensions)/,
    'files with unknown extension'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.streex.gz b.streex.gz))}
    },
    qr/(no DocumentReader implemented|must have extensions)/,
    'extension *.streex.gz is not allowed'
);

stderr_like (
    sub {
         eval { Treex::Core::Run->_get_reader_name_for(qw(a.txtXgz))}
    },
    qr/(no DocumentReader implemented|must have extensions)/,
    'files with unknown extension'
);
