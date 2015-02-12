#!/usr/bin/evn perl

use warnings;
use strict;

use Data::Dumper;

use Test::More tests => 9;
use Test::Deep;

BEGIN {
    use_ok( 'Treex::Tool::TranslationModel::ML::Learner' );
    use_ok( 'Treex::Tool::TranslationModel::ML::Model' );
}

sub new_learner_with_data {
    my ($data, $add_params) = @_;
    
    my $params = {
        learner_type => 'maxent',
        params => {
            smoother => { type => 'gaussian', sigma => 0.99 },
        },
        %$add_params
    };

    my $learner = new_ok( 'Treex::Tool::TranslationModel::ML::Learner' => [ $params ] );

    foreach my $instance (@$data) {
        $learner->see( $instance->{in}, $instance->{out}, $instance->{feats} );
    }
    return $learner;
}

my @data = (
    {in => 'en1', out => 'cs1', feats => ['f1', 'f2', 'f3']},
    {in => 'en1', out => 'cs3', feats => ['f1', 'f4']},
    {in => 'en1', out => 'cs1', feats => ['f1', 'f2', 'f3', 'f5']},
    {in => 'en1', out => 'cs1', feats => ['f5', 'f2', 'f3']},
    {in => 'en1', out => 'cs2', feats => ['f8', 'f4']},
    {in => 'en1', out => 'cs2', feats => ['f1', 'f8', 'f2', 'f5']},
    {in => 'en1', out => 'cs1', feats => ['f1', 'f2', 'f3']},
    {in => 'en1', out => 'cs4', feats => ['f1', 'f2', 'f9']},
    {in => 'en2', out => 'cs4', feats => ['f1', 'f2', 'f5']},
    {in => 'en2', out => 'cs2', feats => ['f1', 'f2', 'f3']},
    {in => 'en2', out => 'cs4', feats => ['f1', 'f5', 'f2']},
    {in => 'en2', out => 'cs1', feats => ['f4', 'f2', 'f8']},
    {in => 'en2', out => 'cs4', feats => ['f1', 'f7', 'f3']},
);
my @out_keys = map {$_->{out}} @data;

my $learner = new_learner_with_data(\@data, {});
my $model = $learner->get_model();
ok($model, "learner returns a model");

my @transls = $model->get_translations('en1', ['f1','f2']);
#print STDERR Dumper(\@transls);

my $variant_format = {
    # is a probability 0.5 +/- 0.5
    prob => num(0.5, 0.5),
    score => ignore(),
    label => any(@out_keys),
    source => 'maxent',
};
cmp_deeply(\@transls, array_each($variant_format), 'translation variants in a correct format');


$model->save('t/maxent.model.gz');
my $loaded_model = Treex::Tool::TranslationModel::ML::Model->new({model_type => 'maxent'});
$loaded_model->load('t/maxent.model.gz');
my @loaded_transls = $loaded_model->get_translations('en1', ['f1','f2']);

my @simpl_transls = map {{prob => int($_->{prob} * 100000), label => $_->{label}}} @transls;
my @simpl_loaded_transls = map {{prob => int($_->{prob} * 100000), label => $_->{label}}} @loaded_transls;
cmp_deeply(\@simpl_transls, \@simpl_loaded_transls, "saving and loading ok");


$learner = new_learner_with_data(\@data, { min_instances => 6 });
$model = $learner->get_model();
ok($model, "learner returns a model");
@transls = $model->get_translations('en2', ['f1','f2']);
is(scalar @transls, 0, "minimum input label count filtering");
