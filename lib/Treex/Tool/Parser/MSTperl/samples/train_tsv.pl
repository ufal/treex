#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::FeaturesControl;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Trainer;

my ($train_file, $model_file, $config_file, $save_tsv) = @ARGV;

my $featuresControl = Treex::Tool::Parser::MSTperl::FeaturesControl->new(config_file => $config_file);
my $reader = Treex::Tool::Parser::MSTperl::Reader->new(featuresControl => $featuresControl);
my $training_data = $reader->read_tsv($train_file);
my $trainer = Treex::Tool::Parser::MSTperl::Trainer->new(featuresControl => $featuresControl);

$trainer->train($training_data);
$trainer->model->store($model_file);
if ($save_tsv) {
    $trainer->model->store_tsv($model_file.'.tsv');
}
