#!/usr/bin/env perl
#===============================================================================
#
#         FILE:  document.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Tomas Kraut (), tomas.kraut@matfyz.cz
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  01/27/11 10:49:47
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;# tests=>2;                      # last test to print


BEGIN{ use_ok('Treex::Core::Document')};

my $doc = Treex::Core::Document->new;

isa_ok ($doc, 'Treex::Core::Document'); 

is(scalar $doc->get_bundles(),0,'Empty doc has no bundles');

my $new_bundle = $doc->create_bundle();

is(scalar $doc->get_bundles(),1,'Now I have one bundle');

my ($name, $value) = ('a','b');

$doc->set_attr($name,$value);

is($value,$doc->get_attr($name));


done_testing();
