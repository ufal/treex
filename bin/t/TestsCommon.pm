package TestsCommon;

use File::Basename;

chdir(dirname(__FILE__));

my $act_dir = dirname(__FILE__);
my $pwd = `pwd`;
my $treex_file = "./../treex";
if ( ! -f $treex_file ) {
    $treex_file = "./../bin/treex";
}

if ( ! -f $treex_file ) {
    my $msg = "DIR: $act_dir; PWD: $pwd; TREEX: $treex_file";
    die($msg);
    
}

our $TREEX_FILE = $treex_file;
our $TREEX_CMD = $^X . " " . $TREEX_FILE;
1;