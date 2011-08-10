#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Treex::Core::Config;

my $TMP_DIR = Treex::Core::Config::tmp_dir();
ok( -d $TMP_DIR, 'Temporary directory is directory' );
ok( -w $TMP_DIR, 'Temporary directory is writable' );

done_testing();
