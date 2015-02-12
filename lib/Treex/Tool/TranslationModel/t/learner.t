#!/usr/bin/evn perl

use warnings;
use strict;

use Data::Dumper;

use Test::More tests => 6;
use Test::Deep;

BEGIN {
    use_ok( 'Treex::Tool::TranslationModel::Static::RelFreq::Learner_new' );
    use_ok( 'Treex::Tool::TranslationModel::ML::Learner' );
    use_ok( 'Treex::Tool::TranslationModel::Static::Model' );
}

sub new_learner_with_data {
    my ($class, $params, $data) = @_;
    my $learner = new_ok( $class => [ $params ] );

    foreach my $instance (@$data) {
        $learner->see( $instance->{in}, $instance->{out}, $instance->{feats} );
    }
    return $learner;
}

my @data = (
    {in => 'en4', out => 'cs1', feats => ['f1']},
    {in => 'en4', out => 'cs2', feats => ['f1']},
    {in => 'en4', out => 'cs3', feats => ['f1']},
    {in => 'en4', out => 'cs4', feats => ['f1']},
    {in => 'en4', out => 'cs5', feats => ['f1']},
    {in => 'en4', out => 'cs6', feats => ['f1']},
    {in => 'en4', out => 'cs7', feats => ['f1']},
    {in => 'en4', out => 'cs8', feats => ['f1']},
);

my $static_learner = new_learner_with_data(
    'Treex::Tool::TranslationModel::Static::RelFreq::Learner_new',
    { max_instances => 4 }, 
    \@data
);
my $static_model = $static_learner->get_model();
my $maxent_learner = new_learner_with_data(
    'Treex::Tool::TranslationModel::ML::Learner',
    {
        learner_type => 'maxent',
        params => {
            smoother => { type => 'gaussian', sigma => 0.99 },
        },
        max_instances => 4,
    },
    \@data
);
my $maxent_model = $maxent_learner->get_model();

my @static_labels = map {$_->{label}} $static_model->get_translations('en4');
my @maxent_labels = map {$_->{label}} $maxent_model->get_translations('en4', ['f1']);
cmp_set(\@static_labels, \@maxent_labels, "maximum input label count filtering");
