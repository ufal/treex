#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use FindBin;
FindBin::again();

use Test::More tests => 46;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

BEGIN {
    note('INIT');
    use_ok('Treex::Tool::Parser::RUR::Config');
    use_ok('Treex::Tool::Parser::RUR::Edge');
    use_ok('Treex::Tool::Parser::RUR::FeaturesControl');
    use_ok('Treex::Tool::Parser::RUR::ModelBase');
    use_ok('Treex::Tool::Parser::RUR::ModelLabelling');
    use_ok('Treex::Tool::Parser::RUR::ModelUnlabelled');
    use_ok('Treex::Tool::Parser::RUR::ModelAdditional');
    use_ok('Treex::Tool::Parser::RUR::Node');
    use_ok('Treex::Tool::Parser::RUR::Parser');
    use_ok('Treex::Tool::Parser::RUR::Labeller');
    use_ok('Treex::Tool::Parser::RUR::Reader');
    use_ok('Treex::Tool::Parser::RUR::RootNode');
    use_ok('Treex::Tool::Parser::RUR::Sentence');
    use_ok('Treex::Tool::Parser::RUR::TrainerBase');
    use_ok('Treex::Tool::Parser::RUR::TrainerLabelling');
    use_ok('Treex::Tool::Parser::RUR::TrainerUnlabelled');
    use_ok('Treex::Tool::Parser::RUR::Writer');
}

my ( $train_file, $test_file, $config_file,
    $unlabelled_model_file, $labelling_model_file ) =
    (
    "$FindBin::Bin/sample_train.tsv",
    "$FindBin::Bin/sample_test.tsv",
    "$FindBin::Bin/sample.config",
    "$FindBin::Bin/sample.model",
    "$FindBin::Bin/sample.lmodel",
    );

my $config = new_ok(
    'Treex::Tool::Parser::RUR::Config' => [
        config_file => $config_file,
        DEBUG => 0,
    ],
    "process config file,"
);

my $reader = new_ok(
    'Treex::Tool::Parser::RUR::Reader' => [ config => $config ],
    "initialize Reader,"
);




note('UNLABELLED TRAINING');

ok( my $training_data = $reader->read_tsv($train_file), "read training data" );

my $trainer = new_ok(
    'Treex::Tool::Parser::RUR::TrainerUnlabelled' => [ config => $config ],
    "initialize Unlabelled Trainer,"
);

ok( $trainer->train($training_data), "perform training" );

ok( $trainer->model->store($unlabelled_model_file), "save model" );

ok( $trainer->model->store_tsv( $unlabelled_model_file . '.tsv' ),
    "save model to tsv"
);

ok( $trainer->model->load($unlabelled_model_file), "load model" );

ok( $trainer->model->load_tsv( $unlabelled_model_file . '.tsv' ),
    "load model to tsv"
);

unlink $unlabelled_model_file . '.tsv';





note('PARSING');

ok( my $test_data = $reader->read_tsv($test_file), "read test data" );

my $sentence_count = scalar( @{$test_data} );

my $parser = new_ok(
    'Treex::Tool::Parser::RUR::Parser' => [ config => $config ],
    "initialize Parser,"
);

ok( $parser->load_model($unlabelled_model_file), "load model" );

my $total_words  = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence ( @{$test_data} ) {

    #parse
    ok(
        my $test_sentence =
            $parser->parse_sentence_internal($correct_sentence),
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
note('no of errors on 47 words: ' . $total_errors);

# version with bug in learning (before rev. 6899)
#is( $total_errors, 27, 'returns on the given data 27 errors' );
# version without the bug (corrected in rev. 6899)
# is( $total_errors, 20, 'returns on the given data 20 errors' );

my $writer = new_ok(
    'Treex::Tool::Parser::RUR::Writer' => [ config => $config ],
    "initialize Writer,"
);

ok( $writer->write_tsv( $test_file . '.out', [@sentences] ), "write out file" );

unlink $test_file . '.out';

unlink $unlabelled_model_file;





note('LABELLED TRAINING');

# TODO test various algorithms (?)

my $ltrainer = new_ok(
    'Treex::Tool::Parser::RUR::TrainerLabelling' => [ config => $config ],
    "initialize Labelling Trainer,"
);

ok( $ltrainer->train($training_data), "perform training" );

ok( $ltrainer->model->store($labelling_model_file), "save model" );

# tsv model load/store not yet implemented
# ok( $ltrainer->model->store_tsv( $labelling_model_file . '.tsv' ),
#     "save model to tsv"
# );

ok( $ltrainer->model->load($labelling_model_file), "load model" );

# tsv model load/store not yet implemented
# ok( $ltrainer->model->load_tsv( $labelling_model_file . '.tsv' ),
#     "load model to tsv"
# );

# tsv model load/store not yet implemented
# unlink $labelling_model_file . '.tsv';




note('LABELLING');

my $labeller = new_ok(
    'Treex::Tool::Parser::RUR::Labeller' => [ config => $config ],
    "initialize Labeller,"
);

ok( $labeller->load_model($labelling_model_file), "load model" );

$total_words  = 0;
$total_errors = 0;
@sentences = ();
foreach my $correct_sentence ( @{$test_data} ) {

    #label
    ok(
        my $test_sentence =
            $labeller->label_sentence_internal($correct_sentence),
        'label sentence'
    );
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount     = $test_sentence->count_errors_labelling(
        $correct_sentence
    );

    $total_words  += $sentenceLength;
    $total_errors += $errorCount;
}

is( $total_words, 47, 'testing on 47 words' );

# still very live version so do not test the performance as it changes often
# is( $total_errors, 20, 'returns on the given data 20 errors' );

ok( $writer->write_tsv( $test_file . '.out', [@sentences] ), "write out file" );

unlink $test_file . '.out';

unlink $labelling_model_file;

