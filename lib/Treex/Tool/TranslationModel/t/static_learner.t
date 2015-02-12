#!/usr/bin/evn perl

use warnings;
use strict;

use Data::Dumper;

use Test::More;
use Test::Deep;

BEGIN {
    if (!$ENV{AUTHOR_TESTING}){
        Test::More::plan( skip_all => 'these tests require export AUTHOR_TESTING=1' )
    } else {
        Test::More::plan( tests => 20 );
    }

    use_ok( 'Treex::Tool::TranslationModel::Static::RelFreq::Learner' );
    use_ok( 'Treex::Tool::TranslationModel::Static::Model' );
}

sub new_learner_with_data {
    my (@data) = @_;
    my $learner = new_ok( 'Treex::Tool::TranslationModel::Static::RelFreq::Learner' );

    foreach my $instance (@data) {
        $learner->see( $instance->{in}, $instance->{out}, $instance->{count} );
    }
    return $learner;
}

my @data = (
    {in => 'en1', out => 'cs1', count => 5 },
    {in => 'en1', out => 'cs3'},
    {in => 'en1', out => 'cs1'},
    {in => 'en1', out => 'cs1'},
    {in => 'en1', out => 'cs2', count => 7 },
    {in => 'en1', out => 'cs2'},
    {in => 'en1', out => 'cs1'},
    {in => 'en1', out => 'cs4'},
    {in => 'en2', out => 'cs4'},
    {in => 'en2', out => 'cs2'},
    {in => 'en2', out => 'cs4', count => 10 },
    {in => 'en2', out => 'cs1'},
    {in => 'en2', out => 'cs4'},
    {in => 'en3', out => 'cs5'},
    {in => 'en3', out => 'cs6'},
);
my @out_keys = map {$_->{out}} @data;

my $learner = new_learner_with_data(@data);
my $model = $learner->train();
ok($model, "learner returns a model");

my @transls = $model->get_translations('en1');
#print STDERR Dumper(\@transls);

my $variant_format = {
    # is a probability 0.5 +/- 0.5
    prob => num(0.5, 0.5),
    label => any(@out_keys),
    source => 'static',
};
cmp_deeply(\@transls, array_each($variant_format), 'translation variants in a correct format');

$model->save('t/static.model.gz');
my $loaded_model = Treex::Tool::TranslationModel::Static::Model->new();
$loaded_model->load('t/static.model.gz');
my @loaded_transls = $loaded_model->get_translations('en1');

my @simpl_transls = map {{prob => int($_->{prob} * 100000), label => $_->{label}}} sort {$a->{label} cmp $b->{label}} @transls;
my @simpl_loaded_transls = map {{prob => int($_->{prob} * 100000), label => $_->{label}}} sort {$a->{label} cmp $b->{label}} @loaded_transls;
cmp_deeply(\@simpl_transls, \@simpl_loaded_transls, "saving and loading ok");

$model->set_prob('en9', 'cs8', 0.3);
@transls = $model->get_translations('en9');
cmp_deeply(\@transls, [{ prob => 0.3, label => 'cs8', source => 'static'}], "set_prob ok");
is( $model->get_prob('en9', 'cs8'), 0.3, "get_prob ok");

$model = $learner->train({min_input_label_count => 3, min_pair_count => 2});
ok($model, "learner returns a model");

@transls = $model->get_translations('en3');
is(scalar @transls, 0, 'minimum input label count filtering');
@transls = $model->get_translations('en1');
is(scalar @transls, 2, 'minimum pair count filtering');

$learner = new_learner_with_data(@data);
$model = $learner->train({max_variants => 2});
ok($model, "learner returns a model");
@transls = $model->get_translations('en1');
is(scalar @transls, 2, 'maximum variants count filtering');

$learner = new_learner_with_data(@data);
$model = $learner->train({min_forward_prob => 0.1});
ok($model, "learner returns a model");
@transls = $model->get_translations('en1');
my @filtered = grep {$_->{prob} < 0.1} @transls;
is(scalar @filtered, 0, 'min forward prob filtering');

$learner = new_learner_with_data(@data);
$model = $learner->train({min_backward_prob => 1.0});
ok($model, "learner returns a model");
@transls = $model->get_translations('en1');
is(scalar @transls, 1, 'min backward prob filtering');
