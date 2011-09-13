#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Parser::MSTperl::FeaturesControl;
use Parser::MSTperl::Reader;
use Parser::MSTperl::Trainer;

my ($train_file, $model_file, $config_file) = @ARGV;

my $featuresControl = Parser::MSTperl::FeaturesControl->new(config_file => $config_file, training => 1);
my $reader = Parser::MSTperl::Reader->new(featuresControl => $featuresControl);
my $training_data = $reader->read_tsv($train_file);
my $trainer = Parser::MSTperl::Trainer->new(featuresControl => $featuresControl);

$trainer->train($training_data);
$trainer->model->store($model_file);
$trainer->model->store_tsv($model_file.'.tsv');
