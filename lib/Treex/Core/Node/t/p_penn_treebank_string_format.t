#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Core::Document;

my $mrg_sample = '
( (S 
    (NP-SBJ 
      (NP (NNP Pierre) (NNP Vinken) )
      (, ,) 
      (ADJP 
        (NP (CD 61) (NNS years) )
        (JJ old) )
      (, ,) )
    (VP (MD will) 
      (VP (VB join) 
        (NP (DT the) (NN board) )
        (PP-CLR (IN as) 
          (NP (DT a) (JJ nonexecutive) (NN director) ))
        (NP-TMP (NNP Nov.) (CD 29) )))
    (. .) ))
';


my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone( 'en');

my $proot = $zone->create_ptree;
#my $child = $proot->create_terminal_child;

$proot->create_from_mrg($mrg_sample);

my @descendants = $proot->get_descendants;


cmp_ok(scalar(@descendants), '>', -10, 'p-tree created from its mrg description');

$document->save('penn_sample.treex');


done_testing();

