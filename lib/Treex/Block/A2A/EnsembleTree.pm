package Treex::Block::A2A::EnsembleTree;

use Treex::Tool::Parser::Ensemble::Ensemble;
use Moose;
use Graph;
use Treex::Core::Common;
use Treex::Tool::ML::Clustering::C_Cluster;

extends 'Treex::Core::Block';
has 'trees' => ( is => 'rw', isa => 'Str', required => 1 );
has 'use_pos' => ( is => 'rw', isa => 'Str');
my $ENSEMBLE;
my %use_tree = ();
my $cluster;
my $fcm;
my %cluster1;
my %cluster2;
my %cluster3;
my %pos_weights;
#must pass into this class a string 'trees' with the format parser#weight~parser#weight  for as many parsers as you want used out of the a-trees
sub BUILD {
  my ($self) = @_;
  
  my @trees_to_process = split( "~", $self->trees );
  foreach my $tree (@trees_to_process) {
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  my %edges = ();
    if($self->use_pos eq "true"){
    $cluster = Treex::Tool::ML::Clustering::C_Cluster->new(); 
    $fcm=$cluster->get_clusters();    
   my @hashes= @{$fcm->centroids};
    %cluster1=%{$hashes[0]};
    %cluster2=%{$hashes[1]};
    %cluster3=%{$hashes[2]};
  
  #  %pos_weights=%{ $fcm->memberships };
  #  my @nnp= @{$pos_weights{"NNP"}};
  #  print "$nnp[0]\t$nnp[1]\t$nnp[2]\n";
    
    #?Organize all the weighting values per POS into a hash
    while( my ($k, $v) = each %{ $fcm->memberships } ) {
	print "key: $k, value: $v.\n";
	my @weights=@{$v};
	#print @weights[0]."\n";
	$pos_weights{$k}{"0"}=@weights[0];
	$pos_weights{$k}{1}=@weights[1];
	$pos_weights{$k}{2}=@weights[2];
	
	#print $pos_weights{$k}{"0"}."\t".$pos_weights{$k}{"1"}."\t".$pos_weights{$k}{"2"}."\n";
         }
      
    # show cluster centroids
   # foreach my $centroid ( @{ $fcm->centroids } ) {
   #   print join "\t", map { sprintf "%s:%.4f", $_, $centroid->{$_} }
   #   keys %{$centroid};
   #   print "\n";
   # }    
    # show clustering result
 #  foreach my $id ( sort { $a cmp $b } keys %{ $fcm->memberships } ) {
 #     printf "%s\t%s\n", $id,
 #     join "\t", map { sprintf "%.4f", $_ } @{ $fcm->memberships->{$id} };
 #   }
    
  }
  if ( !$ENSEMBLE ) {
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
  }
  return;  
}

#this method will process each atree passed to it and add its edges to our edge matrix
sub process_tree_pos {
  my ( $root, $weight_tree, $model ) = @_;
  #model=selecter. We want to get the  weights from pos_weights. Then apply those weights to the 3 clusters which individual weight the parsers.
  my @todo = $root->get_descendants( { ordered => 1 } );
  $ENSEMBLE->set_n( scalar @todo );

  
  foreach my $node (@todo) {
    $ENSEMBLE->add_edge( $node->parent->ord, $node->ord, $weight_tree );    
  }  
}

#Weight edge depending on the POS
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
   if ( exists $use_tree{ $zone->get_atree()->selector } ) {
      if($self->use_pos eq "true"){
	process_tree_pos( $zone->get_atree(),
			  $use_tree{ $zone->get_atree()->selector },$zone->get_atree()->selector );
      }
      else{
      process_tree( $zone->get_atree(),
		    $use_tree{ $zone->get_atree()->selector } );
      }
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
