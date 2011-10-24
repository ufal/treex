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
    #$ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new(
    #{ edges => \%edges } );
  }
  return;
 
}

#this method will add process each atree passed to it and add its edges to our edge matrix
sub process_tree {
  my ($root ) = @_;
  my @todo =  $root->get_descendants( { ordered => 1 } );
  
  # Flatten the tree first, if there was some topology already.
  foreach my $node (@todo) {
   print $node->form;
   print " ";
  }
  print "\n";
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  
  my @zones= $bundle->get_all_zones();

  foreach my $zone (@zones){
  process_tree($zone->get_atree());
  }
} 
1;
__END__