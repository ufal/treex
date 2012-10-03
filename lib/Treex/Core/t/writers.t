#!/usr/bin/env perl
# Testing treex -p and base writers
use strict;
use warnings;
use Test::More;
use File::Basename;

BEGIN {
  Test::More::plan( skip_all => 'these tests require export AUTHOR_TESTING=1' ) if !$ENV{AUTHOR_TESTING};
  Test::More::plan( skip_all => 'these tests require SGE qsub' ) if !`which qsub`;
}

my $command = q{-Len Read::Sentences lines_per_doc=1 Util::Eval document='$document->set_path("dir")' Write::Sentences to=.};

chdir(dirname(__FILE__));
`rm -rf dir; seq 3 | treex $command`;
is(`cat dir/noname002.txt`, "2\n", 'local execution');

`rm -rf dir; seq 3 | treex -pj3 $command`;
is(`cat dir/noname002.txt`, "2\n", 'treex -p execution');
# A bug causes the files are created in the current directory instead of "dir"
# Let's delete also these files
`rm -f noname00?.txt`;

`rm -rf dir *-cluster-run-*`;
done_testing();
