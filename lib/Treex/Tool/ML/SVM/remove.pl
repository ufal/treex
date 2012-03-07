use strict;
use warnings;

my %features;
my $num_of_labels=5;
my $z=0;
my $label="";
my %remove=();

$remove{1}=1;
$remove{2}=1;
$remove{3}=1;
$remove{4}=1;
$remove{5}=1;
while (<>){
  my @tokens=split ("\t",$_);
   my $i=0;
   while($i<(scalar @tokens -1)){
   if(exists $remove{$i}){
   $tokens[$i]="";
   }
   else{
   $tokens[$i]="$tokens[$i]\t";
   }
     $i++;
   }

  if(length($tokens[0])>6){
  }
  
  else{
    print join ("",@tokens);  
  }
  
  
  
    
}


    
      

