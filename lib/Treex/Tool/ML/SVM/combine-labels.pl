use strict;
use warnings;

my %features;
my $num_of_labels=5;
my $z=0;
my $label="";
while (<>){
  my @tokens=split ("\t",$_);
  if(exists $features {$tokens[1]}{$tokens[2]}{$tokens[3]}{$tokens[4]}{$tokens[5]}{$tokens[6]}{$tokens[7]}{$tokens[8]}{$tokens[9]}{$tokens[10]}{$tokens[11]}{$tokens[12]}{$tokens[13]}{$tokens[14]}{$tokens[15]}){
    $features {$tokens[1]}{$tokens[2]}{$tokens[3]}{$tokens[4]}{$tokens[5]}{$tokens[6]}{$tokens[7]}{$tokens[8]}{$tokens[9]}{$tokens[10]}{$tokens[11]}{$tokens[12]}{$tokens[13]}{$tokens[14]}{$tokens[15]}=$features {$tokens[1]}{$tokens[2]}{$tokens[3]}{$tokens[4]}{$tokens[5]}{$tokens[6]}{$tokens[7]}{$tokens[8]}{$tokens[9]}{$tokens[10]}{$tokens[11]}{$tokens[12]}{$tokens[13]}{$tokens[14]}{$tokens[15]} . "-". $tokens[0];
    
  }
  else{
    $features {$tokens[1]}{$tokens[2]}{$tokens[3]}{$tokens[4]}{$tokens[5]}{$tokens[6]}{$tokens[7]}{$tokens[8]}{$tokens[9]}{$tokens[10]}{$tokens[11]}{$tokens[12]}{$tokens[13]}{$tokens[14]}{$tokens[15]}=$tokens[0];
    
  }
  
}

for my $a ( keys %features ) {
 
  for my $b ( keys %{ $features{$a} } ) {    
    for my $c ( keys %{ $features{$a}{$b} } ) {
      for my $d ( keys %{ $features{$a}{$b}{$c}} ) {
	for my $e ( keys %{ $features{$a}{$b}{$c}{$d}} ) {
	  for my $f ( keys %{ $features{$a}{$b}{$c}{$d}{$e}} ) {
	    for my $g ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}} ) {
	      for my $h ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}} ) {
		for my $i ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}} ) {
		  for my $j ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}} ) {
		    for my $k ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}} ) {
		      for my $l ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}{$k}} ) {
			for my $m ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}{$k}{$l}} ) {
			  for my $n ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}{$k}{$l}{$m}} ) {
			    for my $o ( keys %{ $features{$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}{$k}{$l}{$m}{$n}} ) {
		      
     $label="";
      for ($z=1;$z le $num_of_labels;$z++){
	if($features {$a}{$b}{$c}{$d}{$e}{$f}{$g}{$h}{$i}{$j}{$k}{$l}{$m}{$n}{$o}=~ m/$z/){
      $label= $label . "$z";
      }
      }
           
      
      print "$label\t$a\t$b\t$c\t$d\t$e\t$f\t$g\t$h\t$i\t$j\t$k\t$l\t$m\t$n\t$o\n";
      }
		}}}}}}}}}}
      }
    }
    
}

}