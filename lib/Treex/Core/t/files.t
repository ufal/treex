#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use File::Slurp;

my @lines = read_file( \*DATA );
write_file( 'filelist', @lines );
END { unlink 'filelist'; }
chomp @lines;
use_ok('Treex::Core::Files');

my $files = Treex::Core::Files->new( string => '@filelist' );
isa_ok( $files, 'Treex::Core::Files' );
is_deeply( $files->filenames, \@lines, 'Got filenames chomped' );

__DATA__
first.file
second.file
