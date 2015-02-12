#!/usr/bin/env perl

use strict;
use warnings;

use Treex::Tool::TranslationModel::NaiveBayes::Learner;
use Treex::Tool::TranslationModel::NaiveBayes::Model;

my @observations = (
    { input=>'access', output=>'pristup', features=>{pos__N=>1, gov__V=>1} },
    { input=>'access', output=>'pristupovat', features=>{pos__V=>1, gov__A=>1} },
    { input=>'access', output=>'pristup', features=>{pos__N=>1, gov__A=>1} },

    { input=>'right', output=>'doprava', features=>{pos__A=>1, gov__V=>1} },
    { input=>'right', output=>'vpravo', features=>{pos__D=>1, gov__A=>1}},
    { input=>'right', output=>'pravy', features=>{pos__A=>1, gov__N=>1}},
    { input=>'right', output=>'pravy', features=>{pos__D=>1, gov__N=>1}},
    { input=>'right', output=>'pravy', features=>{pos__D=>1, gov__N=>1}},
 );



my $learner = Treex::Tool::TranslationModel::NaiveBayes::Learner->new({feature_cut=>1});

foreach my $observation (@observations) {
    $learner->see(
        $observation->{input},
        $observation->{output},
        $observation->{features},
    );
}


my $model = $learner->get_model;

$model->save('nb_test.pls.gz');

foreach my $observation (@observations) {
    print "input=$observation->{input}\tcorrect=$observation->{output}\tpredicted=".
        $model->predict($observation->{input},$observation->{features})."\n";
}

#my %features = ;
my $features_rf = undef;

print "Test: " . $model->predict('access', $features_rf) . "\n";

print "\nParameters of submodels: \n\n".$model->stringify;
