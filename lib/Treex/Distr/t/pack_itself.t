#!/usr/bin/perl

use strict;
use warnings;
#use Test::More tests => 1;

use Treex::Distr::Treex4CPAN;

Treex::Distr::Treex4CPAN::create_distr({
    module_name => 'Treex::Distr::Treex4CPAN', # name of the main module in the package
    author => 'Zdenek Zabokrtsky',
    email => 'zabokrtsky@ufal.mff.cuni.cz',
    lib => ['treex/lib/Treex/Distr/Treex4CPAN.pm'],
    bin => [],
    t => [],
});



#ok(defined $doc_from_file,'save and load empty treex file');


