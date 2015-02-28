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
use Treex::Tool::Parser::MSTperl::Labeller;

my ( $test_file, $model_file, $config_file, $algorithm, $debug, $pruning ) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => $config_file
);

if (defined $algorithm) {
    $config->labeller_algorithm($algorithm);
}
if (defined $debug) {
    $config->DEBUG($debug);
}
if (defined $pruning) {
    $config->VITERBI_STATES_NUM_THRESHOLD($pruning);
}

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(
    config => $config
);
my $test_data      = $reader->read_tsv($test_file);
my $sentence_count = scalar( @{$test_data} );
print "Going to test on $sentence_count sentences.\n";

my $labeller = Treex::Tool::Parser::MSTperl::Labeller->new(
    config => $config
);
$labeller->load_model($model_file);

my $total_words  = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence ( @{$test_data} ) {
    #    print "SENTENCE: " . $test_sentence->toString() . "\n";

    #parse
    #$labeller->parse_sentence($test_sentence);
    my $test_sentence = $labeller->label_sentence_internal($correct_sentence);
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount     = $test_sentence->count_errors_labelling($correct_sentence);

    #    my $score = 100 - (100*$errorCount/$sentenceLength);
    #    print "score: $score% ($errorCount errors in $sentenceLength words)\n";
    $total_words  += $sentenceLength;
    $total_errors += $errorCount;

    #output
    #    foreach my $child (@{$test_sentence->nodes}) {
    #    print $child->parent->form." -> ".$child->form."\n";
    #    }
}
my $writer = Treex::Tool::Parser::MSTperl::Writer->new(
    config => $config
);

$test_file =~ /^(.*)\/([^\/]+)$/;
my $out_file = "$1/out/$2";
$model_file =~ /.*\/([^\/]+)$/;
$out_file = $out_file . "_" . $1 . ".out";
$writer->write_tsv( $out_file, [@sentences] );

my $total_score = 100 - ( 100 * $total_errors / $total_words );
print "\n";
print "TOTAL SCORE: " .
    "$total_score% ($total_errors errors in $total_words words)\n";

