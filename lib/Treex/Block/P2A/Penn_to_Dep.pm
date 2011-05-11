package Treex::Block::W2A::Penn_to_Dep;

use strict;
use warnings;
use Treex::Tools::Parser::Pennconverter;
use base qw(TectoMT::Block);


my $converter;
my @preorder=();
sub BUILD {
   if (!$converter) {
        $converter = Treex::Tools::Parser::Pennconverter->new();
    }
    
}

sub preorder {
my $node=shift @_;
my @string=();
foreach my $child ($node->get_children()){
push (@preorder,$child);
preorder($child);
}
return @string;
}

sub process_document {

 my ( $self, $document ) = @_;
 
  foreach my $bundle ($document->get_bundles()){
  @preorder=();
#not correct need to do it by children/parent relationship
#get each SentenceP structure and rebuild penn string

#add zone information
my  $p_root = $bundle->get_tree( 'en', 'P');
 #my $p_root = $bundle->get_tree('SEnglishP');
 my @p_all = $p_root->get_descendants();
 my @p_children = $p_root->get_children();

 my $penn=""; 
 my @pairs=();
preorder($p_root);

my $par_count=0;
my $to_pop=0;
my $size=0;
foreach my $p (@preorder){


if(scalar($p->get_children) ==1){
   $penn=$penn." (".$p->get_attr("phrase");
   push (@pairs,scalar ($p->get_children));
$to_pop++;
  }
elsif(scalar($p->get_children) >1){
   $penn=$penn." (".$p->get_attr("phrase")." ";
     push (@pairs,scalar ($p->get_children));
$to_pop++;

  }  
  
 if(scalar($p->get_children()) ==0){
 $size++;
  $penn=$penn." (".$p->get_attr("phrase")." ".$p->get_attr("form").") ";
  my $i=0;
  my $popped=0;
    while ($i<$to_pop){
    my $par_count=pop @pairs;
      if($par_count==1){
	$penn = $penn .")";
	$popped++;
	}
      else{
      $par_count--;
      push(@pairs,$par_count);
      
      $i =$to_pop+1;
      
      }
 
$i++;
 }
 $to_pop=$to_pop-$popped;  
   }
}

$penn = "(S ".$penn.")";

#print "Phrase: ".$penn."\n";
#get the head indices of each term; Indices atrt at 1 to match conll style

my ($output_ref,$indices_ref)= $converter->parse($penn,$size);

 my @output = @$output_ref;
 my @indices = @$indices_ref;


#print join ( " ", @output);
#print "\n";
my $a_root = $bundle->get_tree( 'en', 'A');
#my $a_root = $bundle->get_tree('SEnglishA');
my @a_nodes = $a_root->get_children();

my $counter =0;
#print "-------------\n";
foreach my $a_node (@a_nodes){
#print "$output[$counter] \t $indices[$counter]\n";

$a_node->set_attr( 'conll_deprel', $output[$counter]);
my $index= $indices[$counter]-1;
if($index==-1){
$a_node->set_parent($a_root);
}
else{
#print scalar(@a_nodes)."\t".$index."\n";
$a_node->set_parent($a_nodes[$index]);
}
$counter++;
}

}

}

1;



__END__
 