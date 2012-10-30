#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 5;
use Test::Deep;

BEGIN {
    use_ok('Treex::Tool::ML::VowpalWabbit::Learner');
    use_ok('Treex::Tool::ML::VowpalWabbit::Model');
}

my @data = (
    {class => 'cs1', feats => ['f1', 'f2', 'f3']},
    {class => 'cs1', feats => ['f4', 'f2', 'f8']},
    {class => 'cs1', feats => ['f1', 'f2', 'f3', 'f5']},
    {class => 'cs1', feats => ['f5', 'f2', 'f3']},
    {class => 'cs1', feats => ['f1', 'f2', 'f3']},
    {class => 'cs2', feats => ['f8', 'f4']},
    {class => 'cs2', feats => ['f1', 'f8', 'f2', 'f5']},
    {class => 'cs2', feats => ['f1', 'f2', 'f3']},
    {class => 'cs3', feats => ['f1', 'f4']},
    {class => 'cs4', feats => ['f1', 'f2', 'f9']},
    {class => 'cs4', feats => ['f1', 'f2', 'f5']},
    {class => 'cs4', feats => ['f1', 'f5', 'f2']},
    {class => 'cs4', feats => ['f1', 'f7', 'f3']},
);
my @classes = map {$_->{class}} @data;

srand(1986);
my $passes = 5;

my $learner = new_ok('Treex::Tool::ML::VowpalWabbit::Learner', [{passes => $passes}]);

foreach my $instance (@data) {
    $learner->see($instance->{feats}, $instance->{class});
}

my $model = $learner->learn();
ok($model, 'model learn');

my $score = $model->score(['f1','f2'], 'en1');

my $model_path = 't/toy.model';
$model->save($model_path);
my $new_model = Treex::Tool::ML::VowpalWabbit::Model->new();
$new_model->load($model_path);

my $new_score = $new_model->score(['f1','f2'], 'en1');

is($score, $new_score, "the same score");
