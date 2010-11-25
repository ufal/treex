#!/usr/bin/perl

use Treex::Core::Stream;
use Treex::Core::Scenario;

my $scenario = Treex::Core::Scenario
    ->new({blocks =>[qw(Treex::Block::StreamReader::SentencePerLine
                        Treex::Block::W2A::Tokenize
                        Treex::Block::StreamWriter::SaveAsTreexFiles)]});

my $stream = Treex::Core::Stream->new;

$scenario->apply_on_stream($stream);
