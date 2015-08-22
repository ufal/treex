#!/usr/bin/env perl

use strict;
use warnings;
use File::Slurp;

# replace __USAGE__ with the output of treex --help
# in lib/Treex/Core/Run.pm
my $module_filename = 'lib/Treex/Core/Run.pm';

my $treex = 'bin/treex';
if ( !-x $treex ) {
    $treex = 'treex';
}
if ( -x $treex ) {
    print STDERR "Reading treex usage from $treex --help\n";
    my $usage = `$treex --help 2>&1`;

    # leading space will make it verbatim
    $usage = join "\n", map {" $_"} split( /\n/, $usage );

    my $module_content = File::Slurp::read_file( $module_filename, binmode => ':utf8' );

    if ( $module_content =~ s/__USAGE__/$usage/ ) {
        File::Slurp::write_file( $module_filename, { binmode => ':utf8' }, $module_content );

        #open my $MODULE, '>:utf8', $module_filename or die $!;
        #print $MODULE $module_content;
        #close $MODULE;

        print STDERR "usage filled into $module_filename\n";
    }
}
else {
    print STDERR "Cannot fill usage into $module_filename\n";
}
