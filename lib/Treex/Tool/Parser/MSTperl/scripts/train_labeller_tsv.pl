#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::TrainerLabelling;

my ( $train_file, $model_file, $config_file, $save_tsv, $algorithm, $debug, $pruning ) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => $config_file
);

if (defined $algorithm) {
    $config->labeller_algorithm($algorithm);
}
if (defined $debug) {
    $config->DEBUG($debug);
}
if (defined $pruning) {
    $config->VITERBI_STATES_NUM_THRESHOLD($pruning);
}

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(
    config => $config
);

my $training_data = $reader->read_tsv($train_file);

my $trainer = Treex::Tool::Parser::MSTperl::TrainerLabelling->new(
    config => $config
);

$trainer->train($training_data);
$trainer->model->store($model_file);
if ($save_tsv) {
    $trainer->model->store_tsv( $model_file . '.tsv' );
}
