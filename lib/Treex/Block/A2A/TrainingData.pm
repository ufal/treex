package Treex::Block::A2A::TrainingData;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';
has 'trees'    => ( is => 'rw', isa => 'Str', required => 1 );
has 'language' => ( is => 'rw', isa => 'Str', default  => 'en' );

my @trees;
my @reference_nodes;
my %edges=();
sub BUILD {
  my ($self) = @_;
 @trees= split(",",$self->trees);
  return;
}

#Weight edge depending on the POS
sub process_tree {
  my ($root) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  my $i = 0;
  my $prev_pos="null";
  my $prev_prev_pos="null";
  my $agree_1="";
  
  
  
  foreach my $node (@todo) {
    if ( $node->parent->ord == $reference_nodes[$i]->parent->ord ) {
     my $i=0;
     my $j=0;
     
     while ($i<scalar @trees){
	while ($j<scalar @trees){
	  if($edges{$trees[$i]}{$node->ord}==$edges{$trees[$j]}{$node->ord}){
	    $agree_1=$agree_1."1\t";
	  }
	  else{
	    $agree_1=$agree_1."0\t";
	  }
	  $j++;
	}	
     $i++;
     $j=$i+1;
     }
     
     
#       if($edges{"charniak"}{$node->ord}==$edges{"mst"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"charniak"}{$node->ord}==$edges{"malt"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"charniak"}{$node->ord}==$edges{"zpar"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"stanford"}{$node->ord}==$edges{"mst"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"stanford"}{$node->ord}==$edges{"malt"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"stanford"}{$node->ord}==$edges{"zpar"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"mst"}{$node->ord}==$edges{"malt"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"mst"}{$node->ord}==$edges{"zpar"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
#       
#       if($edges{"malt"}{$node->ord}==$edges{"zpar"}{$node->ord}){
# 	$agree_1=$agree_1."1\t";
#       }
#       else{
# 	$agree_1=$agree_1."0\t";
#       }
      
      print $node->selector . "\t"
      . $node->tag . "\t"
      . $prev_pos . "\t"
      . $prev_prev_pos . "\t"
      . find_bucket( $i, scalar @todo ) . "\t"
      . scalar @todo . "\t"
      . $agree_1 . "\n"
      ;
    }
    $prev_pos=$node->tag;
    $prev_prev_pos=$prev_pos;
    $agree_1="";
    $i++;
  }
}

#return quartile (1=0.. .25    2 = .25 ... .5)
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
  my @zones            = $bundle->get_all_zones();
  my %use_tree         = ();
  my @trees_to_process = split( ",", $self->trees );
  
  foreach my $tree (@trees_to_process) {
    
    $use_tree{$tree} = 1;
  }
  
  my $reference_root = $bundle->get_tree( $self->language, "a", "ref" );
  @reference_nodes = $reference_root->get_descendants( { ordered => 1 } );
  
  
  #make edge matrix to see where they agree
   %edges=();
  foreach my $zone (@zones) {
    if ( $zone->get_atree()->language eq $self->language ) {
      if ( exists $use_tree{ $zone->get_atree()->selector } ) {
	my @todo = $zone->get_atree()->get_descendants( { ordered => 1 } );
	foreach my $node (@todo) {
	  $edges{$zone->get_atree()->selector}{$node->ord}=$node->parent->ord;
	}
      }
    }
    
  }
  
  foreach my $zone (@zones) {
    if ( $zone->get_atree()->language eq $self->language ) {
      if ( exists $use_tree{ $zone->get_atree()->selector } ) {
	process_tree( $zone->get_atree() );
	
      }
    }
    
  }
}

1;
__END__

=pod

=head1 NAME

Treex::Block::A2A::TrainingData

=head1 DESCRIPTION

Create training data from multiple A-trees to be used for a classifier


=head1 AUTHORS

Nathan Green