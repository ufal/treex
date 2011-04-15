#!/usr/bin/env perl
use strict;
use warnings;

use File::Copy;

# To manually restore files modified by cycle_detection_test.pl

#restore a file from its backup
sub restore_file {
    my $filename = shift;
    my $filename_backup = "$filename.cdbup"; #cdbup = cycle detection backup
    move($filename_backup, $filename);
    if (-e $filename) {
        print "Restored $filename\n";
    } else {
        print STDERR "Cannot restore module $filename\n";
    }
}

# THE MAIN PROGRAM

#load commandline params
if (@ARGV == 0) {
    die "usage: ./cycle_detection_restore.pl module_to_restore_1.pm module_to_restore_2.pm module_to_restore_3.pm ...\n";
}

my @modules;
foreach my $argnum (0 .. $#ARGV) {
    my $module = $ARGV[$argnum];
    if (-e "$module.cdbup") {
        restore_file $module;
    } else {
        print "Cannot restore $module, as there is no backup for it.\n";        
        print " (Most probably it was not modified at all, maybe it even is not a module file.)\n";        
    }
}
