#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::More tests => 16;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

BEGIN {
    use_ok('Treex::Tool::Parser::MSTperl::FeaturesControl');
    use_ok('Treex::Tool::Parser::MSTperl::Reader');
    use_ok('Treex::Tool::Parser::MSTperl::Writer');
    use_ok('Treex::Tool::Parser::MSTperl::Parser');
}

my ( $test_file, $model_file, $config_file ) = qw(t/sample_test.tsv t/sample.model t/sample.config);

my $featuresControl = new_ok( 'Treex::Tool::Parser::MSTperl::FeaturesControl' => [ config_file => $config_file ], "process config file," );

my $reader = new_ok( 'Treex::Tool::Parser::MSTperl::Reader' => [ featuresControl => $featuresControl ], "initialize Reader," );

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

is( $total_errors, 27, 'returns on the given data 27 errors' );

my $writer = new_ok( 'Treex::Tool::Parser::MSTperl::Writer' => [ featuresControl => $featuresControl ], "initialize Writer," );

ok( $writer->write_tsv( $test_file . '.out', [@sentences] ), "write out file" );
