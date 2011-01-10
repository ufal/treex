#
#===============================================================================
#
#         FILE:  loadtime.t
#
#  DESCRIPTION:  checks if each module loads within 1 second
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  01/10/11 14:47:02
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;


use File::Find::Rule;
use Time::HiRes qw(time);
my @files = File::Find::Rule->name('*.pm')->in('.');
plan tests => 2 * scalar @files;

for (@files) {
    s/^lib.//;
	s/.pm$//;
	s{[\\/]}{::}g;
	my $before = Time::HiRes::time();
	require_ok($_);
	my $after = Time::HiRes::time();
	my $loadTime = $after-$before;
	ok( $loadTime < 1.0, "$_ loaded within a second ($loadTime s)" );
	#print "$_ : $loadTime\n";
	
	
}


