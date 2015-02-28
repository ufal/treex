#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN,  ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Writer;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Labeller;


# initialize

my ($test_file, $config_file, $model_file, $lmodel_file, $algorithm, $debug, $pruning) = @ARGV;

if (!defined $algorithm) {
    $algorithm = 16;
}
if (!defined $debug) {
    $debug = 1;
}
if (!defined $pruning) {
    $pruning = 1;
}

my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => $config_file,
    labeller_algorithm => $algorithm,
    DEBUG => $debug,
    VITERBI_STATES_NUM_THRESHOLD => $pruning,
);


# input data

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(
    config => $config
);
my $test_data = $reader->read_tsv($test_file);
my $sentence_count = scalar(@{$test_data});
print "Going to test on $sentence_count sentences.\n";


# parser and labeller

my $parser = Treex::Tool::Parser::MSTperl::Parser->new(
    config => $config
);
$parser->load_model($model_file);

my $labeller = Treex::Tool::Parser::MSTperl::Labeller->new(
    config => $config
);
$labeller->load_model($lmodel_file);


# test

my $total_words = 0;
my $total_errors = 0;
my $total_errors_attachment = 0;
my $total_errors_labelling = 0;
my @sentences;
foreach my $correct_sentence (@{$test_data}) {
    # parse and label
    my $parsed_sentence   = $parser->parse_sentence_internal($correct_sentence);
    my $labelled_sentence = $labeller->label_sentence_internal($parsed_sentence);
    push @sentences, $labelled_sentence;
    my $sentenceLength = $labelled_sentence->len();
    my $errorCount = $labelled_sentence->count_errors_attachement_and_labelling(
        $correct_sentence);
    my $errorCountAttachment = $labelled_sentence->count_errors_attachement(
        $correct_sentence);
    my $errorCountLabelling = $labelled_sentence->count_errors_labelling(
        $correct_sentence);
    $total_words += $sentenceLength;
    $total_errors += $errorCount;
    $total_errors_attachment += $errorCountAttachment;
    $total_errors_labelling += $errorCountLabelling;
}

my $writer = Treex::Tool::Parser::MSTperl::Writer->new(
    config => $config
);
$writer->write_tsv( $test_file . '.out', [@sentences] );

my $total_score = 100 - (100*$total_errors/$total_words);
my $total_score_attachment = 100 - (100*$total_errors_attachment/$total_words);
my $total_score_labelling = 100 - (100*$total_errors_labelling/$total_words);
print "\n";
print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words)\n";
print "ATTACHMENT SCORE: $total_score_attachment%\n";
print "LABELLING SCORE: $total_score_labelling%\n";

