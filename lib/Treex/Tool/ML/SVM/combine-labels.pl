use strict;
use warnings;

my %features;
while (<>){
  my @tokens=split ("\t",$_);
  if(exists $features {$tokens[1]}{$tokens[2]}{$tokens[3]}){
    $features {$tokens[1]}{$tokens[2]}{$tokens[3]}=$features {$tokens[1]}{$tokens[2]}{$tokens[3]} . "-". $tokens[0];
    
  }
  else{
    $features {$tokens[1]}{$tokens[2]}{$tokens[3]}=$tokens[0];
    
  }
  
}

for my $a ( keys %features ) {
 
  for my $b ( keys %{ $features{$a} } ) {
    
    for my $c ( keys %{ $features{$a}{$b} } ) {
      print "$a-$b-$c: ";
      print $features {$a}{$b}{$c};
      print "\n";
    }
    
}

}