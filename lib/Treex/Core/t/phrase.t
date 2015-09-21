#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    use_ok('Treex::Core::Phrase');
    use_ok('Treex::Core::Phrase::Term');
    use_ok('Treex::Core::Phrase::NTerm');
}
use Treex::Core::Document;

my $document = new Treex::Core::Document;
my $bundle   = $document->create_bundle();
my $zone     = $bundle->create_zone('en');
my $root     = $zone->create_atree();
my $node     = $root->create_child();
my $tphrase  = new Treex::Core::Phrase::Term ('node' => $node);
my $ntphrase = new Treex::Core::Phrase::NTerm ('head' => $tphrase);
isa_ok($ntphrase->head(), 'Treex::Core::Phrase');
# Topology
ok(!defined($ntphrase->parent()), 'Root $ntphrase has no parent');
is($tphrase->parent(), $ntphrase, 'Parent of $tphrase is $ntphrase');
is($ntphrase->head(), $tphrase,   'Head child of $ntphrase is $tphrase');
ok(!$ntphrase->is_terminal(),     '$ntphrase is not terminal');
ok($tphrase->is_terminal(),       '$tphrase is terminal');
ok($tphrase->is_descendant_of($ntphrase), '$tphrase is descendant of $ntphrase');
cmp_ok(scalar($ntphrase->children()),         '==', 1, '$ntphrase has 1 child');
cmp_ok(scalar($ntphrase->core_children()),    '==', 1, '$ntphrase has 1 core child');
cmp_ok(scalar($ntphrase->nonhead_children()), '==', 0, '$ntphrase has no non-head children');
cmp_ok(scalar($ntphrase->dependents()),       '==', 0, '$ntphrase has no dependent children');
my @children = $ntphrase->children();
is($children[0], $tphrase, '$tphrase is the first child of $ntphrase');
###!!! TODO: There is a lot more to test. Including the other classes (PP, Coordination, Builder).
done_testing();
