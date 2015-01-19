#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Output;
use File::Temp qw(tempfile);
use File::Spec;

BEGIN { require_ok('Treex::Core::Resource') }

SKIP:
{
    skip "May fail when not online", 1 unless ($ENV{AUTHOR_TESTING});
    my $file = Treex::Core::Resource::require_file_from_share('data/models/parser/mst/cs/README');
    ok( -e $file, 'file from resource exists' );
    
    my ($fh, $filename) = tempfile();
    $file = Treex::Core::Resource::require_file_from_share($filename);
    ok( -e $file, 'file with absolute path' );
    
    my ($volume, $dir, $f) = File::Spec->splitpath($filename);
    chdir $dir;
    $file = Treex::Core::Resource::require_file_from_share("./$f");
    ok( -e $file, 'file with relative path' );
    
    unlink $filename;
}
done_testing();

