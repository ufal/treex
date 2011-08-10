#!/usr/bin/env perl
use strict;
use warnings;

use File::Copy;

#
# Description and usage can be found in the Makefile in this directory.
#
# Please do NOT kill this test while running, as it modifies the module files!
# (The modified files are restored at the end of a run.)
# If you do, please run then ./cycle_detection_restore.pl on the same files
# to restore the original files before you do anything else.
# If the test does not exit correctly (dies on fatal error, etc.),
# you also must run ./cycle_detection_restore.pl on the module files.

#backup a file
sub backup_file {
    my $filename        = shift;
    my $filename_backup = "$filename.cdbup";    #cdbup = cycle detection backup
    copy( $filename, $filename_backup );
    if ( -e $filename_backup ) {

        #if (File::Compare::compare($filename, $filename_backup)) { die "Cannot backup $filename!\n"; }
        return 1;
    }
    else {
        die "Cannot backup module $filename!\n";
        return 0;
    }
}

#restore a file from its backup done by backup_file()
sub restore_file {
    my $filename        = shift;
    my $filename_backup = "$filename.cdbup";    #cdbup = cycle detection backup
    if ( -e $filename_backup ) {
        move( $filename_backup, $filename );
        if ( -e $filename ) {
            return 1;
        }
        else {
            print STDERR "Cannot restore module $filename\n";
            return 0;
        }
    }
    else {
        print STDERR "Cannot restore module $filename because $filename_backup does not exist\n";
        return 0;
    }
}

#add memory cycle detection code to module destructor
sub add_cycle_detection {
    my $filenameOut = shift;
    my $filenameIn  = "$filenameOut.cdbup";
    open my $fileIn,  '<:utf8', $filenameIn  or return 0;
    open my $fileOut, '>:utf8', $filenameOut or return 0;

    my $added = 0;
    while (<$fileIn>) {
        if (/^1;$/) {    #end of module -> add cycle detection code here
            print $fileOut 'use Devel::Cycle;
                sub DESTROY
                {
                    my $this = shift;
                    find_cycle($this);
                }
';
            print $fileOut $_;    #copy original line
            $added = 1;
        }
        else {
            print $fileOut $_;    #copy original line
        }
    }

    close $fileIn;
    close $fileOut;

    if ($added) {
        return 1;
    }
    else {
        print STDERR "Cannot add cycle detection code to file $filenameOut, end of module '1;' not found! Perhaps $filenameOut is not a perl module file?\n";
        return 0;
    }

}

#runs silent treex (prints out only fatal errors) on the given scenario
use Treex::Core::Log;
use Treex::Core::Run q(treex);

sub run {
    my $scenario = shift;
    Treex::Core::Log::log_set_error_level('FATAL');
    treex($scenario);
}

# THE MAIN PROGRAM

#load commandline params
if ( @ARGV < 2 ) {
    die "usage: ./cycle_detection_test.pl scenarion_file.scen module_to_test_1.pm module_to_test_2.pm module_to_test_3.pm ...\n";
}
my $scenario = $ARGV[0];
if ( !-e $scenario ) {
    die "scenarion file $scenario does not exist!\n";
}
my @modules;
foreach my $argnum ( 1 .. $#ARGV ) {
    my $module = $ARGV[$argnum];
    if ( -e $module ) {
        push @modules, $module;
    }
    else {
        die "File $module does not exist!\n";
    }
    if ( -e "$module.cdbup" ) {
        die "There exists a cycle test backup of $module!\n"
            . " If there is another instance of cycle test running, please wait for it to stop.\n"
            . " If the previous run did not exit correctly, you must first run\n"
            . " ./cycle_detection_restore.pl on the module files to restore them.\n"
            ;
    }
}

#inform the user
print '
  If a memory cycle is detected, the test will print out information about it
  at the end of its run. Otherwise the test just tells you that it has ended
  and exits.
  
  WARNING:
  Do NOT kill this test while running, as it modifies your module files!
  (The modified files are restored at the end of a run.)
  If you still do so, please run then ./cycle_detection_restore.pl on the same
  files to restore your original files before you make any changes to them.

  If the test does not exit correctly (dies on fatal error, etc.),
  you also must run ./cycle_detection_restore.pl on the module files!!!

';

#backup modules
foreach my $module (@modules) {
    backup_file $module;
}

#add cycle detection to modules
foreach my $module (@modules) {
    my $result = add_cycle_detection $module;
    if ( $result == 0 ) {
        print STDERR "Cannot add cycle detection code to module $module\n";
    }
}

#run treex
print "Running scenario...\n";
run $scenario;
print "Scenario has been run.\n";

#restore modules
foreach my $module (@modules) {
    restore_file $module;
}

#
# Description and usage can be found in the Makefile in this directory.
#
# Copyright 2011 Rudolf Rosa
