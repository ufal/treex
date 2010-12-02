#!/usr/bin/env perl

use Treex::Core::Stream;
use Treex::Core::Scenario;

my $scenario = Treex::Core::Scenario
    ->new({blocks =>[qw(StreamReader::Plain_text StreamWriter::Save_as_numbered_treex)]});

my $stream = Treex::Core::Stream->new;

$scenario->apply_on_stream($stream);
