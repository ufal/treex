#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::FeaturesControl;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Writer;
use Treex::Tool::Parser::MSTperl::Parser;

my ($test_file, $model_file, $config_file) = @ARGV;

my $featuresControl = Treex::Tool::Parser::MSTperl::FeaturesControl->new(config_file => $config_file);

my $reader = Treex::Tool::Parser::MSTperl::Reader->new(featuresControl => $featuresControl);
my $test_data = $reader->read_tsv($test_file);
my $sentence_count = scalar(@{$test_data});
print "Going to test on $sentence_count sentences.\n";

my $parser = Treex::Tool::Parser::MSTperl::Parser->new(featuresControl => $featuresControl);
$parser->load_model($model_file);

my $total_words = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence (@{$test_data}) {
    my $test_sentence = $correct_sentence->copy_nonparsed();
#    print "SENTENCE: " . $test_sentence->toString() . "\n";
    #parse
    $parser->parse_sentence($test_sentence);
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount = $test_sentence->count_errors($correct_sentence);
#    my $score = 100 - (100*$errorCount/$sentenceLength);
#    print "score: $score% ($errorCount errors in $sentenceLength words)\n";
    $total_words += $sentenceLength;
    $total_errors += $errorCount;
    
    #output
#    foreach my $child (@{$test_sentence->nodes}) {
#	print $child->parent->form." -> ".$child->form."\n";
#    }
}
my $writer = Treex::Tool::Parser::MSTperl::Writer->new(featuresControl => $featuresControl);
$writer->write_tsv($test_file.'.out', [@sentences]);

my $total_score = 100 - (100*$total_errors/$total_words);
print "\n";
print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words)\n";

