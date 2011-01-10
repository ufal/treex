#
#===============================================================================
#
#         FILE:  load.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  01/07/11 15:47:38
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;                      # last test to print


use File::Find::Rule;
use Try::Tiny;

my @files = File::Find::Rule->name('*.pm')->in('.');
plan tests => scalar @files;

for (@files) {
    s/^lib.//;
	s/.pm$//;
	s{[\\/]}{::}g;

	require_ok($_);
	
}
