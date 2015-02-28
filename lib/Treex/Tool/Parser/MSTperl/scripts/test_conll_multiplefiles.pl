#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Writer;
use Treex::Tool::Parser::MSTperl::Parser;

my ($config_name, $test_file_before, $test_file_after, @test_files) = @ARGV;

my $config_file = "$config_name.config";
my $model_file = "$config_name.model";

my $config = Treex::Tool::Parser::MSTperl::Config->new(config_file => $config_file);

my $parser = Treex::Tool::Parser::MSTperl::Parser->new(config => $config);
$parser->load_model($model_file);

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(config => $config);

foreach my $test_file (@test_files) {

    my $test_data = $reader->read_tsv(
        $test_file_before . $test_file . $test_file_after);
    my $sentence_count = scalar(@{$test_data});
    print "Going to test on $sentence_count sentences from $test_file.\n";

    my $total_words = 0;
    my $total_errors = 0;
    my @sentences;
    foreach my $correct_sentence (@{$test_data}) {
        #parse
        my $test_sentence = $parser->parse_sentence_internal($correct_sentence);
        push @sentences, $test_sentence;
        my $sentenceLength = $test_sentence->len();
        my $errorCount = $test_sentence->count_errors_attachement($correct_sentence);
        $total_words += $sentenceLength;
        $total_errors += $errorCount;

    }

# my $writer = Treex::Tool::Parser::MSTperl::Writer->new(
#     config => $config
# );
# 
# $ test_file =~ /^(.*)\/([^\/]+)$/;
# my $out_file = "$1/out/$2";
# $model_file =~ /.*\/([^\/]+)$/;
# $out_file = $out_file . "_" . $1 . ".out";
# $writer->write_tsv( $out_file, [@sentences] );

    my $total_score = 100 - (100*$total_errors/$total_words);
    print "\n";
    print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words) on $test_file\n";

}


