package Treex::Block::HamleDT::SVMTree;
use Treex::Tool::Parser::Ensemble::Ensemble;
use Treex::Tool::ML::SVM::SVM;
use Algorithm::SVM::DataSet;
use Moose;
use Graph;
use Treex::Core::Common;

extends 'Treex::Core::Block';
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'treename' => ( is => 'rw', isa => 'Str', default  => 'svm' );
has 'trees'    => ( is => 'rw', isa => 'Str', required => 1 );
my $SVM;
my $POSKEY="/home/green/tectomt/treex/lib/Treex/Tool/ML/SVM/poskey";
my $MODELKEY="/home/green/tectomt/treex/lib/Treex/Tool/ML/SVM/modelkey";
my $ENSEMBLE;
my %poshash;
my %modelhash;
my %weighthash;
my $root_deprel = "ROOT";
my @trees=();
sub BUILD {
  my ($self) = @_;
  @trees= split(",",$self->trees);
    $SVM = Treex::Tool::ML::SVM::SVM->new();
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
    
    open POS, "$POSKEY" or die $!;
    my @lines = <POS>;
    foreach my $line (@lines){
      chomp($line);
    my @tokens = split ("\t",$line);
    $poshash{$tokens[0]}=$tokens[1];
    }
    close (POS);
    
    
    open MODEL, "$MODELKEY" or die $!;
    @lines = <MODEL>;
    foreach my $line (@lines){
      chomp($line);
      my @tokens = split ("\t",$line);
      $modelhash{$tokens[0]}=$tokens[1];
      if(scalar @tokens>2){
	$weighthash{$tokens[0]}=$tokens[2];
      }
      else{
	$weighthash{$tokens[0]}=1;	
      }
    }
    close (MODEL);
    
    
    return;
}

sub find_bucket {
  my ( $index, $length ) = @_;
  
  my $percent = $index / $length;
  
  if ( $percent < .25 ) {
    return 1;
  }
  elsif ( $percent < .5 ) {
    return 2;
  }
  elsif ( $percent < .75 ) {
    return 3;
  }
  return 4;
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  my $tree_root = $bundle->get_tree( $self->language, 'a', $self->treename );  
  my @reference_nodes = $tree_root->get_descendants( { ordered => 1 } ); 
 
  
  my @todo = $tree_root->get_descendants( { ordered => 1 } );    
  
  my $pos=0;
  my $sentence_length=scalar @todo;
  my $quartile=0;
  $ENSEMBLE->set_n( scalar @todo );
  $ENSEMBLE->clear_edges();
  
  my $i=0;
  my $prev_pos="null";
  my $prev_prev_pos="null";
  foreach my $node (@todo){
    
    if(exists $poshash{$node->tag}){
      $pos=$poshash{$node->tag};
    }
    else{
      $pos=0;
    }

  $quartile=find_bucket($i,$sentence_length);
  my $agreement="";

   
    my $j=0;
    my $k=$j;
    
    while ($j<(scalar @trees-1)){
      while ($k<scalar @trees){
	#print $trees[$j]."\t".$trees[$k]."\n";
	my $j_root=$bundle->get_tree( $self->language, 'a', $trees[$j] );
	my @j_nodes=$j_root->get_descendants( { ordered => 1 } );
	my $k_root=$bundle->get_tree( $self->language, 'a', $trees[$k] );
	my @k_nodes=$k_root->get_descendants( { ordered => 1 } );
	
	
	if($j_nodes[$i]->parent->ord==$k_nodes[$i]->parent->ord){
	  $agreement=$agreement."1\t";
	}
	else{
	  $agreement=$agreement."0\t";
	}
	
#	print "j=$j\tk=$k\n";
	$k++;
      }	
      $j++;
      $k=$j;
    }
   # print "j=$j\tk=$k\n";
    #add last model agreement
    $agreement=$agreement."1";;
    
  
#   my $dstest = new Algorithm::SVM::DataSet(Label => "predict",
# 					   Data  => [$pos,$prev_pos,$prev_prev_pos,$quartile,$sentence_length,$agree_1,$agree_2,$agree_3,$agree_4,$agree_5,$agree_6,$agree_7,$agree_8,$agree_9,$agree_10]);

my @features= split ("\t",$agreement);
#print "# of feature=". scalar @features;
#print "\n";
#foreach (@features){
#print $_."\t";
#}
#print "\n";
  my $dstest = new Algorithm::SVM::DataSet(Label => "predict", Data  => [@features]);
 #my $dstest = new Algorithm::SVM::DataSet(Label => "predict",  Data  => [$features[0],$features[1],$features[2],$features[3],$features[4],$features[5],$features[6],$features[7],$features[8],$features[9],$features[10],$features[11],$features[12],$features[13],$features[14],$features[15],$features[16],$features[17],$features[18],$features[19],$features[20],$features[21],$features[22],$features[23],$features[24],$features[25],$features[26],$features[27],$features[28]]);
 									    
   #print "$pos,$prev_pos,$prev_prev_pos,$quartile,$sentence_length,$agree_1,$agree_2,$agree_3,$agree_4,$agree_5\n";					   
 my $predictedModel=  $SVM->predict($dstest);
 $prev_pos=$pos;
 $prev_prev_pos=$prev_pos;

 my @chars = split '', $predictedModel;
 #print $predictedModel."\n";
 for my $m (@chars){
 my $tree_root = $bundle->get_tree( $self->language, 'a', $modelhash{$m} );  
 my @modelNodes = $tree_root->get_descendants( { ordered => 1 } );  

#print $modelhash{$m}."\t".$modelNodes[$i]->parent->ord."->".$node->ord."\n";
$ENSEMBLE->add_edge( $modelNodes[$i]->parent->ord, $node->ord,$weighthash{$m} );
 }
  
  $i++;
  }
 # $ENSEMBLE->print_edge_matrix();
  make_graph( $self, $bundle );
  copy_deprel( $self, $bundle );
}

sub make_graph {
  my ( $self, $bundle ) = @_;
  my $mst = $ENSEMBLE->get_mst();
  #print "mst:".$mst;
  my $node;
  my $tree_root =
  $bundle->get_tree( $self->language, 'a', $self->treename );
  
  my @todo = $tree_root->get_descendants( { ordered => 1, add_self => 1 } );
  
  #flatten the tree first
  foreach $node (@todo) {
    if ( $node->ord != 0 ) {
      $node->set_parent($tree_root);
    }
  }
  my $N = scalar @todo;
  my $i = 0;
  foreach $node (@todo) {
    for ( $i = 0 ; $i < $N ; $i++ ) {
      if ( $mst->has_edge( $node->ord, $i ) ) {
	$todo[$i]->set_parent($node);
	
      }
    }
  }
}

sub copy_deprel {
  
  #Ensemble system only combines structures. Here we will copy the Deprel of any tree that matches the edge.
  # By default the last matching edge will win. If labeled accuracy becomes a problem we can do an ensemble label matching.
  my ( $self, $bundle ) = @_;
  
  # my $reference_root = $bundle->get_tree( $self->language, "a", "charniak" );
  # my @reference_nodes = $reference_root->get_descendants( { ordered => 1 } );
  if($bundle->has_tree( $self->language, 'a', $self->treename )){
    my $tree_root =
    $bundle->get_tree( $self->language, 'a', $self->treename );

    my @todo = $tree_root->get_descendants( { ordered => 1 } );
    
    my @zones = $bundle->get_all_zones();
    foreach my $zone (@zones) {
      if($zone->has_atree()){
	if ( $zone->get_atree()->language eq $self->language ) {
	    my $reference_root = $zone->get_atree();
	    my @reference_nodes =
	    $reference_root->get_descendants( { ordered => 1 } );
	    my $i = 0;
	    foreach my $node (@todo) {
	      if ( $node->parent->ord ==
		$reference_nodes[$i]->parent->ord )
	      {
		$node->set_conll_deprel(
		$reference_nodes[$i]->conll_deprel() );
	      }
	      if ( $node->parent eq $tree_root ) {
		$node->set_conll_deprel($root_deprel);
	      }
	      $i++;
	      
	    }
	    
	  
	}
      }
    }
  }
}

1;
__END__

=pod

=head1 NAME

Treex::Block::HamleDT::EnsembleTree



=head1 DESCRIPTION

This block gathers all a-trees and passes each arc as an edge to  Treex::Tool::Parser::Ensemble::Ensemble 
where more graph algorithms and calculation can take place



=head1 AUTHORS

Nathan Green
