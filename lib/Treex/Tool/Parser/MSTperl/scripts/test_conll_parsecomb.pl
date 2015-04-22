#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Reader;
use Treex::Tool::Parser::MSTperl::Writer;
use Treex::Tool::Parser::MSTperl::ParsedSentencesCombiner;

my ($test_file, $out_file_suffix, $config_name, @parsed_files) = @ARGV;

my $config = Treex::Tool::Parser::MSTperl::Config->new(config_file => $config_name.'.config');
my $reader = Treex::Tool::Parser::MSTperl::Reader->new(config => $config);

my $test_data = $reader->read_tsv($test_file);

# $parsed_sentences[file]->[sentence]
my @parsed_sentences = ();
foreach my $parsed_file (@parsed_files) {
    push @parsed_sentences, $reader->read_tsv($parsed_file);
}

my $parse_combiner = Treex::Tool::Parser::MSTperl::ParsedSentencesCombiner->new();

sub say {
    my ($a) = @_;

    print "$a\n";

    return;
}

my $total_words = 0;
my $total_errors = 0;
my @sentences;
foreach my $correct_sentence (@{$test_data}) {
    my @sentence_parses = ();
    foreach my $parsed_file (@parsed_sentences) {
        my $sentence_parse = shift @$parsed_file;
        push @sentence_parses, $sentence_parse;
    }
    my $test_sentence = $parse_combiner->parse_sentence_internal(\@sentence_parses);
    push @sentences, $test_sentence;
    my $sentenceLength = $test_sentence->len();
    my $errorCount = $test_sentence->count_errors_attachement($correct_sentence);
    $total_words += $sentenceLength;
    $total_errors += $errorCount;
}

my $writer = Treex::Tool::Parser::MSTperl::Writer->new(config => $config);
my $out_file = $test_file . "_" . $out_file_suffix . ".out";
$writer->write_tsv( $out_file, \@sentences );

my $total_score = 100 - (100*$total_errors/$total_words);
print "\n";
print "TOTAL SCORE: $total_score% ($total_errors errors in $total_words words)\n";

