#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::More tests => 12;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

BEGIN {
    use_ok('Treex::Tool::Parser::MSTperl::FeaturesControl');
    use_ok('Treex::Tool::Parser::MSTperl::Reader');
    use_ok('Treex::Tool::Parser::MSTperl::Trainer');
}

my ( $train_file, $model_file, $config_file, $save_tsv ) = qw (t/sample_train.tsv t/sample.model t/sample.config);

my $featuresControl = new_ok( 'Treex::Tool::Parser::MSTperl::FeaturesControl' => [ config_file => $config_file ], "process config file," );

my $reader = new_ok( 'Treex::Tool::Parser::MSTperl::Reader' => [ featuresControl => $featuresControl ], "initialize Reader," );

ok( my $training_data = $reader->read_tsv($train_file), "read training data" );

my $trainer = new_ok( 'Treex::Tool::Parser::MSTperl::Trainer' => [ featuresControl => $featuresControl ], "initialize Trainer," );

ok( $trainer->train($training_data), "perform training" );

ok( $trainer->model->store($model_file), "save model" );

ok( $trainer->model->store_tsv( $model_file . '.tsv' ), "save model to tsv" );

ok( $trainer->model->load($model_file), "load model" );

ok( $trainer->model->load_tsv( $model_file . '.tsv' ), "load model to tsv" );

