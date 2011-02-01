#
#===============================================================================
#
#         FILE:  bundle.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  02/01/11 12:55:11
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;# tests => 1;                      # last test to print

BEGIN {
use_ok('Treex::Core::Bundle');
use_ok('Treex::Core::Document');
}

my $bundle = Treex::Core::Document->new->create_bundle();

isa_ok($bundle, 'Treex::Core::Bundle');

done_testing();

