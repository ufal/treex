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

my ( $train_file, $model_file, $config_file, $save_tsv, $algorithm, $debuglevel ) = @ARGV;

if (!defined $algorithm) {
    $algorithm = 0;
}
if (!defined $debuglevel) {
    $debuglevel = 1;
}
my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => $config_file,
    labeller_algorithm => $algorithm,
    DEBUG => $debuglevel,
);

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(
    config => $config
);

my $training_data = $reader->read_tsv($train_file);

my $trainer = Treex::Tool::Parser::MSTperl::TrainerLabelling->new(
    config => $config
);

$trainer->train($training_data);

$trainer->store_model($model_file);
if ($save_tsv) {
    $trainer->store_model_tsv( $model_file . '.tsv' );
}
