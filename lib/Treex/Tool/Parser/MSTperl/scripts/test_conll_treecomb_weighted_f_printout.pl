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
use Treex::Tool::Parser::MSTperl::ParserCombiner;

# %parsers = (model_filename, weight, model_filename, weight...)
# this wraper requires all parsers to use the same config
# (although this is not strictly required by ParserCombiner itself)
my ($test_file, $config_name, $weights_name, %parsers) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(config_file => $config_name.'.config');

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(config => $config);
my $test_data = $reader->read_tsv($test_file);
my $sentence_count = scalar(@{$test_data});
print "Going to test on $sentence_count sentences.\n";

my @parsers = ();
my @weights = ();
while (my ($model_lang, $parser_weight) = each %parsers) {
    my $parser = Treex::Tool::Parser::MSTperl::Parser->new(config => $config);
    $parser->load_model($model_lang.'_'.$config_name.'.model');
    push @parsers, $parser;
    push @weights, $parser_weight;
}

my $parser_combiner = Treex::Tool::Parser::MSTperl::ParserCombiner->new(
    parsers => \@parsers, weights => \@weights,
);

my $total_words = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence (@{$test_data}) {
    #parse
    my $test_sentence = $parser_combiner->parse_sentence_internal($correct_sentence);
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount = $test_sentence->count_errors_attachement($correct_sentence);
    $total_words += $sentenceLength;
    $total_errors += $errorCount;
    
}

my $writer = Treex::Tool::Parser::MSTperl::Writer->new(
    config => $config
);

my $out_file = $test_file . "_" . $config_name . "_" . $weights_name . ".out";
$writer->write_tsv( $out_file, [@sentences] );

my $total_score = 100 - (100*$total_errors/$total_words);
print "\n";
print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words)\n";

