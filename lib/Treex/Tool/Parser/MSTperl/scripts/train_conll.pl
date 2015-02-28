#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::TrainerUnlabelled;

my ($train_file, $model_file, $config_file, $save_tsv) = @ARGV;

if (!$config_file) {
    $config_file = "$model_file.config";
    $model_file = "$model_file.model";
}

my $config = Treex::Tool::Parser::MSTperl::Config->new(config_file => $config_file);
my $reader = Treex::Tool::Parser::MSTperl::Reader->new(config => $config);
my $training_data = $reader->read_tsv($train_file);
my $trainer = Treex::Tool::Parser::MSTperl::TrainerUnlabelled->new(config => $config);

$trainer->train($training_data);
$trainer->model->store($model_file);
if ($save_tsv) {
    $trainer->model->store_tsv($model_file.'.tsv');
}
