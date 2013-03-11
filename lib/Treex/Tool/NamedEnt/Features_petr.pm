package Treex::Tool::NamedEnt::Features_petr;

use strict;
use warnings;

use Data|::Dumper;


#######################
# Pouze polusny modul #
# #####################


sub load_tmt {

}


sub load_plain {
   
#not finished!

    my $infile = shift;
    
    open my $I, $infile or die "Cannot read input file: $!\n";
    
    while (<$I>) {
      chomp;
      my @words = split;
      for my $i (0..$#words) {
        if ((substr $words[$i], 0, 1) eq "<" ) {
          if ((substr $words[$i+1], -1, 1) eq ">") {
            if ($i-1 >= 0) {
              my $prev;
              if((substr$words[$i-1], 0, 1) eq "<") {
                if ($i-2 >= 0) {
                  $prev = $words[$i-2];
                } else {
                  $prev = "N/A\t";
                }
              } else {
                $prev = $words[$i-1];
              }
              $prev =~ s/>//g;
              print "$prev\t";
            } else {
              print "N/A\t";
            }
            if ($i+2 <= $#words) {
              if ((substr $words[$i+2], 0, 1) eq "<" ) {
                my $next = $words[$i+3];
                $next =~ s/>//g;
                print "$next\t";
              } else {
                print "$words[$i+2]\t";
              }
            } else {
              print "N/A\t";
            }
            my $type = $words[$i];
            while ((index($type, '<')) != -1) {
              $type = substr $type, index($type, '<')+1;
            }
            print "$type\n";
          }
        }
      }
    }
}
