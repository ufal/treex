package Treex::Block::A2A::EnsembleTree;

use Treex::Tool::Parser::Ensemble::Ensemble;
use Moose;
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
   $ENSEMBLE->add_edge($node->ord,$node->parent->ord);
  }
  $ENSEMBLE->print_edge_matrix();
  print "\n";
}

sub process_bundle {
  my ( $self, $bundle ) = @_;  
  my @zones= $bundle->get_all_zones();
  $ENSEMBLE->clear_edges();
  foreach my $zone (@zones){
  process_tree($zone->get_atree());
  }
} 
1;
__END__