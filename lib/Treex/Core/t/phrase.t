#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    use_ok('Treex::Core::Phrase');
    use_ok('Treex::Core::Phrase::Term');
    use_ok('Treex::Core::Phrase::NTerm');
    use_ok('Treex::Core::Phrase::PP');
}
use Treex::Core::Document;

my $document = new Treex::Core::Document;
my $bundle   = $document->create_bundle();
my $zone     = $bundle->create_zone('en');
my $root     = $zone->create_atree();
my $node     = $root->create_child();
my $prep     = $root->create_child();
my $dep1     = $root->create_child();
my $tphrase  = new Treex::Core::Phrase::Term ('node' => $node);
my $tprep    = new Treex::Core::Phrase::Term ('node' => $prep);
my $tdep1    = new Treex::Core::Phrase::Term ('node' => $dep1);
my $ntphrase = new Treex::Core::Phrase::NTerm ('head' => $tphrase);
my $pphrase  = new Treex::Core::Phrase::PP ('fun' => $tprep, 'arg' => $ntphrase, 'fun_is_head' => 0, 'deprel_at_fun' => 0);
$tdep1->set_parent($ntphrase);
isa_ok($tphrase->node(),  'Treex::Core::Node');
isa_ok($ntphrase->node(), 'Treex::Core::Node');
isa_ok($pphrase->node(),  'Treex::Core::Node');
isa_ok($ntphrase->head(), 'Treex::Core::Phrase');
isa_ok($pphrase->fun(),   'Treex::Core::Phrase');
isa_ok($pphrase->arg(),   'Treex::Core::Phrase');
# Topology
ok(!defined($pphrase->parent()),  'Root $pphrase has no parent');
is($ntphrase->parent(), $pphrase, 'Parent of $ntphrase is $pphrase');
is($tprep->parent(), $pphrase,    'Parent of $tprep is $pphrase');
is($tphrase->parent(), $ntphrase, 'Parent of $tphrase is $ntphrase');
is($tdep1->parent(), $ntphrase,   'Parent of $tdep1 is $ntphrase');
is($ntphrase->head(), $tphrase,   'Head child of $ntphrase is $tphrase');
is($pphrase->fun(), $tprep,       'Function child of $pphrase is $tprep');
is($pphrase->arg(), $ntphrase,    'Argument child of $pphrase is $ntphrase');
ok($tphrase->is_terminal(),       '$tphrase is terminal');
ok(!$ntphrase->is_terminal(),     '$ntphrase is not terminal');
ok(!$pphrase->is_terminal(),      '$pphrase is not terminal');
ok($tphrase->is_descendant_of($ntphrase), '$tphrase is descendant of $ntphrase');
ok($tphrase->is_descendant_of($pphrase),  '$tphrase is descendant of $pphrase');
ok($tdep1->is_descendant_of($ntphrase),   '$tdep1 is descendant of $ntphrase');
ok($tdep1->is_descendant_of($pphrase),    '$tdep1 is descendant of $pphrase');
ok($ntphrase->is_descendant_of($pphrase), '$ntphrase is descendant of $pphrase');
ok($tprep->is_descendant_of($pphrase),    '$tprep is descendant of $pphrase');
cmp_ok(scalar($ntphrase->children()),         '==', 2, '$ntphrase has 2 children');
cmp_ok(scalar($ntphrase->core_children()),    '==', 1, '$ntphrase has 1 core child');
cmp_ok(scalar($ntphrase->nonhead_children()), '==', 1, '$ntphrase has 1 non-head child');
cmp_ok(scalar($ntphrase->dependents()),       '==', 1, '$ntphrase has 1 dependent child');
cmp_ok(scalar($pphrase->children()),          '==', 2, '$pphrase has 2 children');
cmp_ok(scalar($pphrase->core_children()),     '==', 2, '$pphrase has 2 core children');
cmp_ok(scalar($pphrase->nonhead_children()),  '==', 1, '$pphrase has 1 non-head child');
cmp_ok(scalar($pphrase->dependents()),        '==', 0, '$pphrase has no dependent children');
my @children = $ntphrase->children();
is($children[0], $tphrase, '$tphrase is the first child of $ntphrase');
# Links to the underlying dependency tree.
is($tphrase->node(),  $node, '$node is the head node of $tphrase');
is($ntphrase->node(), $node, '$node is the head node of $ntphrase');
is($tprep->node(),    $prep, '$prep is the head node of $tprep');
is($pphrase->node(),  $node, '$node is the head node of $pphrase');
# Tree transformations.
$ntphrase->set_head($tdep1);
is($tphrase->parent(), $ntphrase, 'Parent of $tphrase is still $ntphrase');
is($tdep1->parent(), $ntphrase,   'Parent of $tdep1 is still $ntphrase');
is($ntphrase->head(), $tdep1,     'Head of $ntphrase is now $tdep1');
is($ntphrase->node(), $dep1,      '$dep1 is now the head node of $ntphrase');
is($pphrase->node(),  $dep1,      '$dep1 is now the head node of $pphrase');
###!!! TODO: There is a lot more to test. Including the other classes (Coordination, Builder).
done_testing();
