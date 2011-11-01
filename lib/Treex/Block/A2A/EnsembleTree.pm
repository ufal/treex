package Treex::Block::A2A::EnsembleTree;

use Treex::Tool::Parser::Ensemble::Ensemble;
use Moose;
use Graph;
use Treex::Core::Common;

extends 'Treex::Core::Block';
has 'trees' => ( is => 'rw', isa => 'Str', required => 1 );
my $ENSEMBLE;
my %use_tree = ();

#must pass into this class a string 'trees' with the format parser#weight-parser#weight  for as many parsers as you want used out of the a-trees
sub BUILD {
  my ($self) = @_;
  
  my @trees_to_process = split( "-", $self->trees );
  foreach my $tree (@trees_to_process) {
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  my %edges = ();
  
  if ( !$ENSEMBLE ) {
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
  }
  return;
  
}

#this method will process each atree passed to it and add its edges to our edge matrix
sub process_tree {
  my ( $root, $weight_tree ) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  $ENSEMBLE->set_n( scalar @todo );
  foreach my $node (@todo) {
    $ENSEMBLE->add_edge( $node->parent->ord, $node->ord, $weight_tree );
    
  }
  
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  my @zones = $bundle->get_all_zones();
  $ENSEMBLE->clear_edges();
  foreach my $zone (@zones) {
    
    # if (    $zone->get_atree()->selector ne "ref"
    # and $zone->get_atree()->selector ne "" )
    if ( exists $use_tree{ $zone->get_atree()->selector } ) {
      process_tree( $zone->get_atree(),
		    $use_tree{ $zone->get_atree()->selector } );
    }
  }
  make_graph($bundle);
}

sub make_graph {
  my ($bundle) = @_;
  my $mst = $ENSEMBLE->get_mst();
  my $node;
  my $tree_root = $bundle->get_tree( 'en', 'a' );
  
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

1;
__END__

=pod

=head1 NAME

Treex::Block::A2A::EnsembleTree



=head1 DESCRIPTION

This block gathers all a-trees and passes each arc as an edge to  Treex::Tool::Parser::Ensemble::Ensemble 
where more graph algorithms and calculation can take place



=head1 AUTHORS

Nathan Green
