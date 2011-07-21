package Treex::Block::W2A::EN::ParseCharniak;

use 5.008;
use strict;
use warnings;

use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::Parser::Charniak::Charniak;
use Treex::Tool::Parser::Charniak::Node;
use Treex::Core::Node::P;
use Clone;
use Moose;

my $parser;
my $string_to_parse;

my @results;
my @final_tree;
my $self;
my @m_nodes=();
my $a_root;
my $document;
my $fsfile;
my $node;
my $parent;
my @processing_nodes=();
my @structure_nodes=();
my $current_node;


#sub process_atree { 
sub process_document {  
($self,$document) = @_;
my @bundles = $document->get_bundles();
my @sentences=();
foreach my $bundle ($document->get_bundles) {
  my $sentence = $bundle->get_zone($self->language, $self->selector)->sentence;
  push (@sentences, $sentence);
  }
  



#($self,@m_nodes) = @_;
# ( $self, $a_root ) = @_;
 
 #   my @a_nodes = $a_root->get_descendants( { ordered => 1 } );
  #  foreach my $bundle ($document->get_bundles())
   # 	{
   	 @processing_nodes=();
 	 @structure_nodes=();
	 @final_tree=();
	#Get Each Sentence Bundle
      #  my $m_root  = $bundle->get_tree('SEnglishM');
	#Get each child in Bundle... in this case we are looking for each word that was tokenized
     #   my @m_nodes = $m_root->get_children;
	
	#Check for EMpty sentences        
	#print "m_nodes".@m_nodes."\n";
#	if ( @a_nodes == 0 ) {
       #     Report::fatal "Impossible to parse an empty sentence. Bundle id=" . $bundleno;
 #       }
	#Get all the words per sentence with corrisponding ids
       # my @words            = map { $_->get_attr('form') } @m_nodes;
       # my @ids              = map { $_->get_attr('id') } @m_nodes;
	
#	my @words = ();
my $sentence_counter=0;
foreach my $s (@sentences){
my @words = split (" ", $s);
# 	foreach my $a_node (@a_nodes) {
# 	  push (@words,$a_node->get_attr('form'));
# 	 # print $anode_chunks_ref;
# 	  }
	#create sentence to parse surrounded by <s> sentence </s>	
 	$string_to_parse="<s> ";
 	$string_to_parse.= join(" ", @words);
 	$string_to_parse.=" </s> \n ";
#	print $string_to_parse."\n";

$sentences[$sentence_counter]=$string_to_parse;
$sentence_counter++;
	}
	#$parser =Treex::Tool::Parser::Charniak::Charniak->new();
# 	
# 
# my $tree_root =	$parser->parse(@words);
$parser =Treex::Tool::Parser::Charniak::Charniak->new();
my @tree_roots =	$parser->parse_document(@sentences);
# 
# my @root_children = @{$tree_root->children};
# $tree_root=$root_children[0];

  
# 	   my $p_root = $bundle->create_tree('SEnglishP' );
# 		push(@structure_nodes,$p_root);
# 		push(@processing_nodes,$tree_root);
# 		write_branch();

	 

#	

}

sub write_branch{
 

 while(scalar(@processing_nodes>0)){
 my Treex::Tool::Parser::Charniak::Node($node) = shift(@processing_nodes);
 $current_node=shift(@structure_nodes);

 my @node_children = @{$node->children};
 push (@processing_nodes,@node_children);


 foreach my $n (@node_children) { 
 my @node_grandchildren = @{$n->children};	


	if(scalar(@node_grandchildren)>0 ){		
                my $nonterminal = $current_node->create_child;
              
		
                $nonterminal->set_attr( 'phrase',   $n->term ); 
		
                $nonterminal->get_tied_fsnode->{'#name'} = 'nonterminal';
	

	push (@structure_nodes,$nonterminal);
	}
	else{
 		$current_node->set_attr( 'form',  $n->term );
                $current_node->set_attr( 'tag',   $node->term ); 
		$current_node->get_tied_fsnode->{'#name'} = 'terminal';
           	push (@structure_nodes,$current_node);

	}


}
	


}#end while
}


1;
=over




