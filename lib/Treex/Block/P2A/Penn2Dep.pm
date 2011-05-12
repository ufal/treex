package Treex::Block::P2A::Penn2Dep;

use strict;
use warnings;
use Treex::Tools::Phrase2Dep::Pennconverter;
use Moose;
use MooseX::FollowPBP;
use Treex::Core::Common;


my $converter;
my @preorder=();
sub BUILD {
   if (!$converter) {
        $converter = Treex::Tools::Phrase2Dep::Pennconverter->new();
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

#get each SentenceP structure and rebuild penn string

#add zone information
#my  $p_root = $bundle->get_zone($self->language,$self->selector)->get_ptree;
#my  $p_root = $bundle->get_zone('en',$self->selector)->get_ptree;
 my  $p_root = $bundle->get_zone('en','src')->get_ptree;
 
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

#  $penn=$penn." (".$p->get_attr("phrase")." ".$p->get_attr("form").") ";
   $penn=$penn." (".$p->get_attr("tag")." ".$p->get_attr("form").") ";
 
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
#print "PENN $penn \n";
#$penn = "(S ".$penn.")";


#get the head indices of each term; Indices atrt at 1 to match conll style

my ($output_ref,$indices_ref)= $converter->parse($penn,$size);

 my @output = @$output_ref;
 my @indices = @$indices_ref;


#print join ( " ", @output);
#print "\n";
#my $a_root = $bundle->get_zone($self->language,$self->selector)->get_atree;
#my $a_root = $bundle->get_zone('en',$self->selector)->get_atree;
my $a_root = $bundle->get_zone('en','src')->get_atree;
#my $a_root = $bundle->get_tree('SEnglishA');
my @a_nodes = $a_root->get_descendants({ordered=>1});


foreach my $a_node (@a_nodes) {
  $a_node->set_parent($a_root);
}

my $counter =0;
#print "-------------\n";
foreach my $a_node (@a_nodes){
#print "$output[$counter] \t $indices[$counter]\n";

$a_node->set_attr( 'conll_deprel', $output[$counter]);
my $index= $indices[$counter]-1;
if($index==-1){
print scalar(@a_nodes)."\t".scalar(@indices)."\t". $a_node->get_attr("form")."\t".$index."\n";
$a_node->set_parent($a_root);
}
else{
print scalar(@a_nodes)."\t".scalar(@indices)."\t". $a_node->get_attr("form")."\t".$index."\n";
$a_node->set_parent($a_nodes[$index]);
}
$counter++;
}

}

}

1;



__END__
 