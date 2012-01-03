package Treex::Block::A2A::OracleTree;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my @reference_nodes;
my @oracle_nodes;
has 'trees' => ( is => 'rw', isa => 'Str', required => 1 );
has 'language' => ( is => 'rw', isa => 'Str', default =>'en');
my %use_tree = ();

#must pass into this class a string 'trees' with the format parser#weight~parser#weight  for as many parsers as you want used out of the a-trees

sub BUILD {
  my ($self) = @_;
  my @trees_to_process = split( "~", $self->trees );
  
  #print "Trees used in Oracle=".$self->trees;
  foreach my $tree (@trees_to_process) {
    
    # $use_tree{$_}='1';
    my ( $sel, $weight ) = split( "#", $tree );
    $use_tree{$sel} = $weight;
  }
  return;
  
}

#this method will process each atree passed to it and add its edges to our edge matrix
sub process_tree {
  my ($root) = @_;
  my @todo = $root->get_descendants( { ordered => 1 } );
  
  my $i = 0;
  foreach my $node (@todo) {
    if ( $node->parent->ord == $reference_nodes[$i]->parent->ord ) {
      $oracle_nodes[ $i + 1 ]
      ->set_parent( $oracle_nodes[ $node->parent->ord ] );
    }
    $i++;
  }
  
}

sub process_bundle {
  my ( $self, $bundle ) = @_;
  my $reference_root = $bundle->get_tree( $self->language, "a", "ref" );
  my $oracle_root    = $bundle->get_tree( $self->language, "a", "oracle" );
  @reference_nodes = $reference_root->get_descendants( { ordered => 1 } );
  @oracle_nodes =
  $oracle_root->get_descendants( { ordered => 1,, add_self => 1 } );
  
  #flatten the tree first
  foreach my $node (@oracle_nodes) {
    if ( $node->ord != 0 ) {
      $node->set_parent($oracle_root);
    }
  }
  my @zones = $bundle->get_all_zones();
  foreach my $zone (@zones) {
    
    #do not include reference orancle or read in tree as they include to correct anser typically
    if ( exists $use_tree{ $zone->get_atree()->selector } ) {
      process_tree( $zone->get_atree() );
    }
  }
  
}

1;
__END__

=pod

=head1 NAME

Treex::Block::A2A::EnsembleTree



=head1 DESCRIPTION

This block gathers all a-trees and compares them to a reference tree. Any edge they have in common is added to a new tree called Oracle



=head1 AUTHORS

Nathan Green
