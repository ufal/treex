#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Core::Document;

my @mrg_samples = (
"
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
" => 28,
"
( (FRAG 
(PP-LOC (IN In) 
(NP 
(NP (NNP Painter) (POS 's) )
(NN office) ))
(NP-TMP (DT this) (NN evening) )
(. .) ))
" => 11,
"
( ('' '') 
(S 
(NP-SBJ (NNP Shayne) )
(VP (VBD nodded) 
(ADVP-MNR (RB grimly) )))
(. .) )
" => 9,
);

my $document = Treex::Core::Document->new;
my $bundle   = $document->create_bundle;
my $zone     = $bundle->create_zone('en');

my $counter=1;
while (@mrg_samples){
    my ($mrg_sample, $expected_nodes) = splice @mrg_samples, 0, 2;
    my $proot = $zone->create_ptree;
    $proot->create_from_mrg($mrg_sample);
    my @descendants = $proot->get_descendants;

    is( scalar(@descendants), $expected_nodes, "p-tree no. $counter created from its mrg description" );
    $counter++;
    $zone->remove_tree('p');
}

done_testing();

