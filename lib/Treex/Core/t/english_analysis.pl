#!/usr/bin/perl

use Treex::Core::Stream;
use Treex::Core::Scenario;

my $scenario = Treex::Core::Scenario
    ->new({blocks =>[qw(Treex::Block::StreamReader::SentencePerLine language=en sentences_per_document=2
                        Treex::Block::W2A::EN::Tokenize
                        Treex::Block::StreamWriter::SaveAsTreexFiles file_stem=test)]});

my $stream = Treex::Core::Stream->new;

$scenario->apply_on_stream($stream);
