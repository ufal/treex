#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Writer;
use Treex::Tool::Parser::MSTperl::MultiModelParser;

# %models = (filename, weight, filename, weight...)
my ($test_file,  $config_file, %models) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(config_file => $config_file);

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(config => $config);
my $test_data = $reader->read_tsv($test_file);
my $sentence_count = scalar(@{$test_data});
print "Going to test on $sentence_count sentences.\n";

my $parser = Treex::Tool::Parser::MSTperl::MultiModelParser->new(config => $config);
while (my ($model_file, $model_weight) = each %models) {
    $parser->load_model($model_file, $model_weight);
}

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
print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words)\n";

