package Treex::Block::A2A::EnsembleTree;

use Treex::Tool::Parser::Ensemble::Ensemble;
use Moose;
use Graph;
use Treex::Core::Common;
use Treex::Tool::ML::Clustering::C_Cluster;

extends 'Treex::Core::Block';
has 'trees'        => ( is => 'rw', isa => 'Str', required => 1 );
has 'use_pos'      => ( is => 'rw', isa => 'Str', default  => 'false' );
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'ensemblename' => ( is => 'rw', isa => 'Str', default  => 'ensemble' );
my $ENSEMBLE;
my $root_deprel = "ROOT";
my $cluster;
my $fcm;
my %cluster1;
my $sumcluster1 = 0;
my %cluster2;
my $sumcluster2 = 0;
my %cluster3;
my $sumcluster3 = 0;
my %pos_weights;
my %cluster4;
my $sumcluster4 = 0;
my %cluster5;
my $sumcluster5 = 0;
my %cluster6;
my $sumcluster6 = 0;
my %cluster7;
my $sumcluster7 = 0;
my %cluster8;
my $sumcluster8 = 0;

#must pass into this class a string 'trees' with the format parser#weight~parser#weight  for as many parsers as you want used out of the a-trees
sub BUILD {
  my ($self) = @_;
  print "TREES" . $self->trees;
  print "\n";
  
  # if ( !$ENSEMBLE ) {
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
    
    # }
    return;
}

#this method will process each atree passed to it and add its edges to our edge matrix
sub process_tree_pos {
  my ( $root, $weight_tree, $model ) = @_;
  
  #model=selecter. We want to get the  weights from pos_weights. Then apply those weights to the 3 clusters which individual weight the parsers.
  my @todo = $root->get_descendants( { ordered => 1 } );
  $ENSEMBLE->set_n( scalar @todo );
  
  #print  "$model\t".($cluster1{$model}/$sumcluster1)."\n";
  #print $model."\t".(($cluster1{$model}/$sumcluster1)*$pos_weights{"NNP"}{"0"})."\t".(($cluster1{$model}/$sumcluster1)*$pos_weights{"NNP"}{"1"})."\t".(($cluster1{$model}/$sumcluster1)*$pos_weights{"NNP"}{"2"})."\n";
  #my $num_of_clusters=3;
  
  foreach my $node (@todo) {
    my $w;
    
    #print $node->tag;
    if ( exists $pos_weights{ $node->tag } ) {
      $w =
      ( ( $cluster1{$model} / $sumcluster1 ) *
      $pos_weights{ $node->tag }{"0"} ) +
      ( ( $cluster2{$model} / $sumcluster2 ) *
      $pos_weights{ $node->tag }{"1"} ) +
      ( ( $cluster3{$model} / $sumcluster3 ) *
      $pos_weights{ $node->tag }{"2"} );
      
      #+ (($cluster4{$model}/$sumcluster4)*$pos_weights{$node->tag}{"3"})+ (($cluster5{$model}/$sumcluster5)*$pos_weights{$node->tag}{"4"})+ (($cluster6{$model}/$sumcluster6)*$pos_weights{$node->tag}{"5"})+ (($cluster7{$model}/$sumcluster7)*$pos_weights{$node->tag}{"6"})+ (($cluster8{$model}/$sumcluster8)*$pos_weights{$node->tag}{"7"})
    }
    else {
      my $uni_weight = .333;
      
      #3
      $w =
      ( ( $cluster1{$model} / $sumcluster1 ) * $uni_weight ) +
      ( ( $cluster2{$model} / $sumcluster2 ) * $uni_weight ) +
      ( ( $cluster3{$model} / $sumcluster3 ) * $uni_weight );
      
    }
    
    #exponential $w= $w ** exp
    
     $w= $w ** 10;
    $ENSEMBLE->add_edge( $node->parent->ord, $node->ord, $w );
    
    #$ENSEMBLE->multiply_edge( $node->parent->ord, $node->ord, $w );
    
  }
}

#Weight edge depending on the POS
sub process_tree {
  my ( $root, $weight_tree ) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  $ENSEMBLE->set_n( scalar @todo );
 # $weight_tree = $weight_tree ** 10;
  
  #$weight_tree= 2 ** $weight_tree;
  
  #$weight_tree= (-1* log ($weight_tree));
  #$weight_tree=1;
 # print "WEIGHT=$weight_tree\n";
  foreach my $node (@todo) {
    
    $ENSEMBLE->add_edge( $node->parent->ord, $node->ord, $weight_tree );
    
    #$ENSEMBLE->multiply_edge( $node->parent->ord, $node->ord, $weight_tree );
    
  }
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  my @zones = $bundle->get_all_zones();
  $ENSEMBLE->clear_edges();
  my %use_tree = ();
  my @trees_to_process = split( "~", $self->trees );
  foreach my $tree (@trees_to_process) {
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  
  if ( $self->use_pos eq "true" ) {
    $cluster = Treex::Tool::ML::Clustering::C_Cluster->new();
    $fcm     = $cluster->get_clusters();
    my @hashes = @{ $fcm->centroids };
    %cluster1 = %{ $hashes[0] };
    %cluster2 = %{ $hashes[1] };
    %cluster3 = %{ $hashes[2] };
    
    #     %cluster4=%{$hashes[3]};
    #     %cluster5=%{$hashes[4]};
    #    %cluster6=%{$hashes[5]};
    #    %cluster7=%{$hashes[6]};
    #    %cluster8=%{$hashes[7]};
    
    while ( my ( $k, $v ) = each %use_tree ) {
      $sumcluster1 += $cluster1{$k};
      $sumcluster2 += $cluster2{$k};
      $sumcluster3 += $cluster3{$k};
      
      #       $sumcluster4+=$cluster4{$k};
      #       $sumcluster5+=$cluster5{$k};
      #       $sumcluster6+=$cluster6{$k};
      #       $sumcluster7+=$cluster7{$k};
      #       $sumcluster8+=$cluster8{$k};
    }
    
    #?Organize all the weighting values per POS into a hash
    while ( my ( $k, $v ) = each %{ $fcm->memberships } ) {
      
      #print "key: $k, value: $v.\n";
      my @weights = @{$v};
      
      #print @weights[0]."\n";
      $pos_weights{$k}{"0"} = $weights[0];
      $pos_weights{$k}{"1"} = $weights[1];
      $pos_weights{$k}{"2"} = $weights[2];
      
      # 	$pos_weights{$k}{"3"}=$weights[3];
      # 	$pos_weights{$k}{"4"}=$weights[4];
      # 	$pos_weights{$k}{"5"}=$weights[5];
      # 	$pos_weights{$k}{"6"}=$weights[6];
      # 	$pos_weights{$k}{"7"}=$weights[7];
      #print $pos_weights{$k}{"0"}."\t".$pos_weights{$k}{"1"}."\t".$pos_weights{$k}{"2"}."\n";
    }
  }
 
  foreach my $zone (@zones) {
    if($zone->has_atree()){
    if ( $zone->get_atree()->language eq $self->language ) {
      if ( exists $use_tree{ $zone->get_atree()->selector } ) {
	if ( $self->use_pos eq "true" ) {
	  process_tree_pos(
	  $zone->get_atree(),
			   $use_tree{ $zone->get_atree()->selector },
			   $zone->get_atree()->selector
			   );
	}
	else {
	  process_tree( $zone->get_atree(),
			$use_tree{ $zone->get_atree()->selector } );
	}
      }
      }
    }
  }
 
  make_graph( $self, $bundle );
  copy_deprel( $self, $bundle );
  
}

sub make_graph {
  my ( $self, $bundle ) = @_;
  my $mst = $ENSEMBLE->get_mst();
  my $node;
  if($bundle->has_tree( $self->language, 'a', $self->ensemblename )){
  my $tree_root =
  $bundle->get_tree( $self->language, 'a', $self->ensemblename );
  
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
}

sub copy_deprel {
  
  #Ensemble system only combines structures. Here we will copy the Deprel of any tree that matches the edge.
  # By default the last matching edge will win. If labeled accuracy becomes a problem we can do an ensemble label matching.
  my ( $self, $bundle ) = @_;
  
  # my $reference_root = $bundle->get_tree( $self->language, "a", "charniak" );
  # my @reference_nodes = $reference_root->get_descendants( { ordered => 1 } );
  if($bundle->has_tree( $self->language, 'a', $self->ensemblename )){
  my $tree_root =
  $bundle->get_tree( $self->language, 'a', $self->ensemblename );
  
  my %use_tree = ();
  my @trees_to_process = split( "~", $self->trees );
  foreach my $tree (@trees_to_process) {
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  
  my @todo = $tree_root->get_descendants( { ordered => 1 } );
  
  my @zones = $bundle->get_all_zones();
  foreach my $zone (@zones) {
    if($zone->has_atree()){
    if ( $zone->get_atree()->language eq $self->language ) {
      if ( exists $use_tree{ $zone->get_atree()->selector } ) {
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
