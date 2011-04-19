#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Run;

use Test::More;
use Test::Output;

# checking execution of treex exactly as from the command line

sub bash_system {
    my ($command) = @_;
    system ('bash', '-c', $command);
}

my $test_data_file = 'dummy.treex';

my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);
$doc->save('2'.$test_data_file);

my $commands = <<'EOF';
treex -q -- dummy.treex      # reading an empty file
treex -q -s -- dummy.treex   # reading and saving an empty file
treex -q -g '*dummy.treex'   # postponed wildcard expansion
EOF


foreach my $command (split /\n/,$commands) {
    my ($command,$comment) = split '#',$command;
    combined_is( sub { bash_system $command },'',"$comment: $command");
}

my %more_commands = (
  q(echo | treex -q -Len Read::Text Util::Eval document='print 1;') => '1',
  q(echo | treex -q -Len Read::Text Util::Eval document='print "hello";') => 'hello',
  q(echo | treex -q -Len Read::Text Util::Eval document='print "a=b";') => 'a=b',
  q(echo | treex -q -Len Read::Text Util::Eval document='$_="a=b";print;') => 'a=b',
);

while(my ($command, $output) = each %more_commands){
    combined_is( sub { bash_system $command }, $output, "$command # $output");    
}


unlink glob "*dummy.treex";

done_testing;
