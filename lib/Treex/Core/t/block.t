#
#===============================================================================
#
#         FILE:  block.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  01/28/11 16:36:54
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;# tests => 1;                      # last test to print

BEGIN{ use_ok('Treex::Core::Block')};

my $block = Treex::Core::Block->new;

isa_ok($block, 'Treex::Core::Block');



done_testing();
