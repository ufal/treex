package Treex::Block::A2A::EnsembleTree;

use Treex::Tool::Parser::Ensemble::Ensemble;
use Moose;
use Graph;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my $ENSEMBLE;

sub BUILD {
  my ($self) = @_;
 
  my %edges=();
  
  if ( !$ENSEMBLE) {
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
  }
  return;
 
}

#this method will process each atree passed to it and add its edges to our edge matrix
sub process_tree {
  my ($root ) = @_;
  my @todo =  $root->get_descendants( { ordered => 1 } );  
  $ENSEMBLE->set_n(scalar @todo); 
  foreach my $node (@todo) {
    $ENSEMBLE->add_edge($node->parent->ord,$node->ord);
  # print $node->ord."->".$node->parent->ord."\n";
  }

}

sub process_bundle {
  my ( $self, $bundle ) = @_;  
  my @zones= $bundle->get_all_zones();
  $ENSEMBLE->clear_edges();
  foreach my $zone (@zones){
  process_tree($zone->get_atree());
  }
  $ENSEMBLE->print_edge_matrix();
  print "\n";
  make_graph($bundle);
} 

sub make_graph {
  my ( $bundle ) = @_;
  my $mst=$ENSEMBLE->get_mst();
  my $node;
print "MST ".$mst;
my $tree_root = $bundle->get_tree( 'en', 'a');

my @todo =  $tree_root->get_descendants( { ordered => 1,add_self=>1 } );  

#flatten the tree first
foreach $node (@todo) {
  if($node->ord !=0){
  $node->set_parent($tree_root);
  }
}
my $N=scalar @todo;
my $i=0;
foreach $node (@todo) {
  for($i=0;$i<$N;$i++){
  if($mst->has_edge($node->ord,$i)){
  #  print "::".$node->ord."\t".$i."\n";
  $todo[$i]->set_parent($node);
  }
  }
}


}

1;
__END__