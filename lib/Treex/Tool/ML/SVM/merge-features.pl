use strict;
use warnings;

my %features;
my $label="";
while (<>){
  my @tokens=split ("\t",$_);
  my $label=$tokens[0];
  my $feature_vector="";
  for(my $i=1;$i<scalar @tokens;$i++){
  $feature_vector=$feature_vector.$tokens[$i];
  }
  
  if(exists $features{$feature_vector}){
    #check to see if model already in label
    if($features{$feature_vector} =~ m/$label/i){
    #do nothing already included  

    }
    else{
    #find the proper place
    my $inserted="false";
    my $temp_label= $features{$feature_vector};
   # print "$label into $temp_label=";
     for (my $j=0;$j<length($temp_label);$j++){
     if($label<substr ($temp_label,$j,1)){
     #insert label here
     $inserted="true";
     
     if($j==0){
       $features{$feature_vector}=$label.$features{$feature_vector};
     }
     else{
     $features{$feature_vector}=substr($temp_label, 0, $j) . $label . substr($temp_label, $j);
     }
    
     }
     }
    
     if($inserted eq "false"){
       $features{$feature_vector}=$features{$feature_vector}."$label";
     }
  #   print "$features{$feature_vector}\n";
    }
  }
  else{
  
  $features{$feature_vector}=$label
  }
  
  $feature_vector="";
}


#print

while ( my ($key, $value) = each(%features) ) {
  print "$value\t";
  for(my $i=0;$i<length($key)-1;$i++){
  print substr($key,$i,1)."\t";
  }
  print substr($key,length($key),1)."\n";  
}