#!/usr/bin/env perl
package DummyNode;
use strict;
use warnings;
sub new {my ($class, $parent, $label)=@_; bless [$parent, $label], $class;}
sub get_parent{$_[0][0]}
sub label{$_[0][1]}

my $n0  = DummyNode->new(undef,'n0');
my $n1  = DummyNode->new($n0,'n1');
my $n2  = DummyNode->new($n0,'n2');
my $n3  = DummyNode->new($n0,'n3');
my $n11 = DummyNode->new($n1,'n11');
my $n12 = DummyNode->new($n1,'n12');
my $n21 = DummyNode->new($n2,'n21');
my $n22 = DummyNode->new($n2,'n22');
my $n23 = DummyNode->new($n2,'n23');
my $n31 = DummyNode->new($n3,'n31');
my $n311 = DummyNode->new($n31,'n311');

my @tasks = (
    [[$n1],           $n1, []],
    [[$n1,$n11],      $n1, []],
    [[$n1,$n11,$n12], $n1, []],
    [[$n1,$n2],       $n0, [$n0]],
    [[$n11,$n12],     $n1, [$n1]],
    [[$n11,$n22],     $n0, [$n1,$n2,$n0]],
    [[$n311,$n3],     $n3, [$n31]],
);

use Treex::Tool::Algorithm::TreeUtils;
use Test::More;
plan tests => scalar @tasks;

foreach my $task (@tasks){
    my ($in_nodes_rf, $root, $added_rf) = @$task;
    my $input = join ',', map {$_->label} @$in_nodes_rf;
    my ($r, $a_rf) = Treex::Tool::Algorithm::TreeUtils::find_minimal_common_treelet(@$in_nodes_rf);
    my $expected = 'root='.$root->label . ' added=' . join(',', sort map {$_->label} @$added_rf);
    my $got = 'root='.$r->label . ' added=' . join(',', sort map {$_->label} @$a_rf);
    is($got,$expected,"$input -> $expected");
}

