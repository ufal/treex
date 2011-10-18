#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use FindBin;
FindBin::again();

use Test::More tests => 32;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

BEGIN {
    note('INIT');
    use_ok('Treex::Tool::Parser::MSTperl::Config');
    use_ok('Treex::Tool::Parser::MSTperl::Edge');
    use_ok('Treex::Tool::Parser::MSTperl::FeaturesControl');
    use_ok('Treex::Tool::Parser::MSTperl::Model');
    use_ok('Treex::Tool::Parser::MSTperl::Node');
    use_ok('Treex::Tool::Parser::MSTperl::Parser');
    use_ok('Treex::Tool::Parser::MSTperl::Reader');
    use_ok('Treex::Tool::Parser::MSTperl::RootNode');
    use_ok('Treex::Tool::Parser::MSTperl::Sentence');
    use_ok('Treex::Tool::Parser::MSTperl::TrainerBase');
    use_ok('Treex::Tool::Parser::MSTperl::TrainerLabelling');
    use_ok('Treex::Tool::Parser::MSTperl::TrainerUnlabelled');
    use_ok('Treex::Tool::Parser::MSTperl::Writer');
}

my ( $train_file, $test_file, $model_file, $config_file, $save_tsv ) =
    (
    "$FindBin::Bin/sample_train.tsv",
    "$FindBin::Bin/sample_test.tsv",
    "$FindBin::Bin/sample.model",
    "$FindBin::Bin/sample.config"
    );

my $config = new_ok(
    'Treex::Tool::Parser::MSTperl::Config' => [ config_file => $config_file ],
    "process config file,"
);

my $reader = new_ok(
    'Treex::Tool::Parser::MSTperl::Reader' => [ config => $config ],
    "initialize Reader,"
);

note('UNLABELLED TRAINING');

ok( my $training_data = $reader->read_tsv($train_file), "read training data" );

my $trainer = new_ok(
    'Treex::Tool::Parser::MSTperl::TrainerUnlabelled' => [ config => $config ],
    "initialize Trainer,"
);

ok( $trainer->train($training_data), "perform training" );

ok( $trainer->model->store($model_file), "save model" );

ok( $trainer->model->store_tsv( $model_file . '.tsv' ),
    "save model to tsv"
);

ok( $trainer->model->load($model_file), "load model" );

ok( $trainer->model->load_tsv( $model_file . '.tsv' ),
    "load model to tsv"
);

unlink $model_file . '.tsv';

note('PARSING');

ok( my $test_data = $reader->read_tsv($test_file), "read test data" );

my $sentence_count = scalar( @{$test_data} );

my $parser = new_ok(
    'Treex::Tool::Parser::MSTperl::Parser' => [ config => $config ],
    "initialize Parser,"
);

ok( $parser->load_model($model_file), "load model" );

my $total_words  = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence ( @{$test_data} ) {

    #parse
    ok(
        my $test_sentence =
            $parser->parse_sentence_unlabelled($correct_sentence),
        'parse sentence'
    );
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount     = $test_sentence->count_errors_attachement(
        $correct_sentence
    );

    $total_words  += $sentenceLength;
    $total_errors += $errorCount;
}

is( $total_words, 47, 'testing on 47 words' );

# version with bug in learning (before rev. 6899)
#is( $total_errors, 27, 'returns on the given data 27 errors' );
# version without the bug (corrected in rev. 6899)
is( $total_errors, 20, 'returns on the given data 20 errors' );

my $writer = new_ok(
    'Treex::Tool::Parser::MSTperl::Writer' => [ config => $config ],
    "initialize Writer,"
);

ok( $writer->write_tsv( $test_file . '.out', [@sentences] ), "write out file" );

unlink $test_file . '.out';

unlink $model_file;

