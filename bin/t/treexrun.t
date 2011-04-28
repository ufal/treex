#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Core::Run;
use Test::More;
use File::Slurp;

# We want to check execution of treex exactly as from the command line.
# Originally, we tried to
# use Test::Output;
# and then is_combined(), but this does not check output of "system" calls,
# so we must use temporary output file.
my $combined_file = 'combined.out';
sub is_bash_combined_output {
    my ($command, $expected_output, $description) = @_;
    system ('bash', '-c', $command . "> $combined_file 2>&1");
    my $content = read_file($combined_file);
    return is($content, $expected_output, $description);
}

END{
   unlink $combined_file;
   unlink glob "*dummy.treex";
}

# prepare dummy input files
my $test_data_file = 'dummy.treex';
my $doc = Treex::Core::Document->new();
$doc->save($test_data_file);
$doc->save('2'.$test_data_file);

my @tasks = (
  [q(treex -q -- dummy.treex), ''],    # reading an empty file
  [q(treex -q -s -- dummy.treex), ''], # reading and saving an empty file
  [q(treex -q -g '*dummy.treex'), ''], # postponed wildcard expansion
  [q(echo | treex -q -Len Read::Text Util::Eval document='print 1;'), '1'],  # @ARGV contains q{document=print 1;}

# It is questionable whether we want to allow the following four constructions
# [q(echo | treex -q -Len Read::Text Util::Eval document=\'print 1;\'), '1'],# @ARGV contains q{document='print}, q{1;'}
# [q(echo | treex -q -Len Read::Text Util::Eval document=\"print 1;\"), '1'],# @ARGV contains q{document="print}, q{1;"}
# [q(echo | treex -q -Len Read::Text Util::Eval document='"print 1;"'), '1'],# @ARGV contains q{document="print 1;"}
# [q(echo | treex -q -Len Read::Text Util::Eval document="'print 1;'"), '1'],# @ARGV contains q{document='print 1;'}

  [q(echo | treex -q -Len Read::Text Util::Eval document='print "hello";'), 'hello'],
  [q(echo | treex -q -Len Read::Text Util::Eval document="print 'hello';"), 'hello'],
  [q(echo | treex -q -Len Read::Text Util::Eval document='my @a=("#","is not a comment");print $#a;'), '1'],
  [q(echo | treex -q -Len Read::Text Util::Eval document='print "a=b  c";'), 'a=b  c'],
  [q(echo | treex -q -Len Read::Text Util::Eval document='$_="a=b";print;'), 'a=b'],
  [q(echo | treex -q -Len Read::Text Util::Eval document='my $code_with_newlines;
                                                          print 1;'), '1'],
);

foreach my $task_rf (@tasks){
    my ($command, $expected_output) = @$task_rf;
    is_bash_combined_output($command, $expected_output, $command);
}

done_testing;
