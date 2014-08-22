#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::TrainerUnlabelled;

my ( $train_file, $model_file, $config_file, $save_tsv ) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => $config_file
);

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(
    config => $config
);

my $training_data = $reader->read_tsv($train_file);

my $trainer = Treex::Tool::Parser::MSTperl::TrainerUnlabelled->new(
    config => $config
);

$trainer->train($training_data);
$trainer->parser->model->store($model_file);
if ($save_tsv) {
    $trainer->parser->model->store_tsv( $model_file . '.tsv' );
}
