#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use FindBin;
FindBin::again();

use Test::More tests => 24;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

note( 'INIT' );

BEGIN {
    use_ok('Treex::Tool::Parser::MSTperl::FeaturesControl');
    use_ok('Treex::Tool::Parser::MSTperl::Reader');
    use_ok('Treex::Tool::Parser::MSTperl::Trainer');
    use_ok('Treex::Tool::Parser::MSTperl::Writer');
    use_ok('Treex::Tool::Parser::MSTperl::Parser');
}

my ( $train_file, $test_file, $model_file, $config_file, $save_tsv ) =
    ("$FindBin::Bin/sample_train.tsv",
     "$FindBin::Bin/sample_test.tsv",
     "$FindBin::Bin/sample.model",
     "$FindBin::Bin/sample.config");

my $featuresControl = new_ok( 'Treex::Tool::Parser::MSTperl::FeaturesControl' => [ config_file => $config_file ], "process config file," );

my $reader = new_ok( 'Treex::Tool::Parser::MSTperl::Reader' => [ featuresControl => $featuresControl ], "initialize Reader," );



note( 'TRAINING' );

ok( my $training_data = $reader->read_tsv($train_file), "read training data" );

my $trainer = new_ok( 'Treex::Tool::Parser::MSTperl::Trainer' => [ featuresControl => $featuresControl ], "initialize Trainer," );

ok( $trainer->train($training_data), "perform training" );

ok( $trainer->model->store($model_file), "save model" );

ok( $trainer->model->store_tsv( $model_file . '.tsv' ), "save model to tsv" );

ok( $trainer->model->load($model_file), "load model" );

ok( $trainer->model->load_tsv( $model_file . '.tsv' ), "load model to tsv" );

unlink $model_file . '.tsv';



note( 'PARSING' );

ok( my $test_data = $reader->read_tsv($test_file), "read test data" );

my $sentence_count = scalar( @{$test_data} );

my $parser = new_ok( 'Treex::Tool::Parser::MSTperl::Parser' => [ featuresControl => $featuresControl ], "initialize Parser," );

ok( $parser->load_model($model_file), "load model" );

my $total_words  = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence ( @{$test_data} ) {
    my $test_sentence = $correct_sentence->copy_nonparsed();

    #parse
    ok( $parser->parse_sentence($test_sentence), 'parse sentence' );
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount     = $test_sentence->count_errors($correct_sentence);

    $total_words  += $sentenceLength;
    $total_errors += $errorCount;
}

is( $total_words, 47, 'testing on 47 words' );

# version with bug in learning (before rev. 6899)
#is( $total_errors, 27, 'returns on the given data 27 errors' );
# version without the bug (corrected in rev. 6899)
is( $total_errors, 20, 'returns on the given data 20 errors' );

my $writer = new_ok( 'Treex::Tool::Parser::MSTperl::Writer' => [ featuresControl => $featuresControl ], "initialize Writer," );

ok( $writer->write_tsv( $test_file . '.out', [@sentences] ), "write out file" );

unlink $test_file . '.out';

unlink $model_file;


