#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Slurp;
use File::Basename;
use Treex::Core::Document;
my $PMFile = dirname(__FILE__) . "/TestsCommon.pm";
require $PMFile;

eval { use Test::Command; 1 } or plan skip_all => 'Test::Command required.' if $@;

BEGIN {
    if ( $^O =~ /^MSWin/ ) {
        Test::More::plan( skip_all => 'this test is not applicable under MS Windows' );
    }
}

my @tasks  = (
    [ q(treex -q -- dummy.treex),                                        '', 0 ],     # reading an empty file
    [ q(treex -q -s -- dummy.treex),                                     '', 0 ],     # reading and saving an empty file
    [ q(treex -q -- '!*dummy.treex'),                                    '', 0 ],     # postponed wildcard expansion
    [ q(echo | treex -q -Len Read::Text Util::Eval document='print 0;'), '0', 0 ],    # @ARGV contains q{document=print 0;}

    # It is questionable whether we want to allow the following four constructions
    # [q(echo | treex -q -Len Read::Text Util::Eval document=\'print 1;\'), '1'],# @ARGV contains q{document='print}, q{1;'}
    # [q(echo | treex -q -Len Read::Text Util::Eval document=\"print 1;\"), '1'],# @ARGV contains q{document="print}, q{1;"}
    # [q(echo | treex -q -Len Read::Text Util::Eval document='"print 1;"'), '1'],# @ARGV contains q{document="print 1;"}
    # [q(echo | treex -q -Len Read::Text Util::Eval document="'print 1;'"), '1'],# @ARGV contains q{document='print 1;'}

    [ q(echo | treex -q -Len Read::Text Util::Eval document='print "hello";'),                            'hello', 0 ],
    [ q(echo | treex -q -Len Read::Text Util::Eval document="print 'hi';"),                               'hi', 0 ],
    [ q(echo | treex -q -Len Read::Text Util::Eval document='my @a=("#","is not a comment");print $#a;'), '1', 0 ],
    [ q(echo | treex -q -Len Read::Text Util::Eval document='print "a=b  c";'),                           'a=b  c', 0 ],
    [ q(echo | treex -q -Len Read::Text Util::Eval document='$_="a=b";print;'),                           'a=b', 0 ],
    [   q(echo | treex -q -Len Read::Text Util::Eval document='my $code_with_newlines;
                                                          print 2;'), '2', 0
    ],
    [ qq(echo | treex -q -Len Read::Text ./scenarios/print3.scen),       '3', 0 ],
    [ qq(echo | treex -q -Len Read::Text ./scenarios/scen_in_scen.scen), '4', 0 ],    # scenario file in scenario file

    # try to confuse the scenario parser with a parameter which looks like scenario
    [ q(echo | treex -q -Len Read::Treex from=confuse.scen), '', 0 ],

    # parameters with quotes
    [ q(echo | treex -q -Len Read::Sentences Util::Eval param= document='print $self->_args->{param};'),   '', 0 ],
    [ q(echo | treex -q -Len Read::Sentences Util::Eval param="" document='print $self->_args->{param};'), '', 0 ],
    [ q(echo | treex -q -Len Read::Sentences Util::Eval param='' document='print $self->_args->{param};'), '', 0 ],
    [ q(echo | treex -q -Len Read::Sentences Util::Eval param=" " document='print $self->_args->{param};'), ' ', 0 ],
    [ q(echo | treex -q -Len Read::Sentences Util::Eval param=' ' document='print $self->_args->{param};'), ' ', 0 ],
);

plan tests => 2 * scalar @tasks;

# We want to check execution of treex exactly as from the command line.
# Originally, we tried to
# use Test::Output;
# and then is_combined(), but this does not check output of "system" calls,
# so we must use temporary output file.
my $combined_file = 'combined.out';

SKIP: {

    chdir(dirname(__FILE__));

    my $cmd_base = $TestsCommon::TREEX_CMD;;
    my $TREEX = "$cmd_base";

    # prepare dummy input files
    my $test_data_file1    = './dummy.treex';
    my $test_data_file2    = './dummy2.treex';
    my $confuse_data_file = './confuse.scen';

    my $doc               = Treex::Core::Document->new();
    $doc->save($test_data_file1);
    $doc->save($test_data_file2 );
    $doc->save($confuse_data_file);

    $doc->set_description("aaaa");

#    skip 'We run different versions of treex binary', scalar @tasks if $perl_v ne $sys_v;
    foreach my $task_rf (@tasks) {
        my ( $command, $expected_output, $exit_code ) = @$task_rf;
        my $original_cmd = $command;
        $command =~ s/treex/$TREEX/;

        my $cmd_test = Test::Command->new( cmd => $command );

        $cmd_test->exit_is_num($exit_code, $original_cmd);
        $cmd_test->stdout_is_eq($expected_output, $original_cmd);
        $cmd_test->run;

        #is_bash_combined_output( $command, $expected_output, $original_cmd );
    }
}

#done_testing;
END {
    if ( $^O !~ /^MSWin/ ) {
        unlink $combined_file;
        unlink glob "./dummy*.treex*";
        unlink "./confuse.scen";
    }
}
