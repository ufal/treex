package Treex::Block::A2A::SVMTree;
use Treex::Tool::Parser::Ensemble::Ensemble;
use Treex::Tool::ML::SVM::SVM;
use Algorithm::SVM::DataSet;
use Moose;
use Graph;
use Treex::Core::Common;

extends 'Treex::Core::Block';
has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );
has 'treename' => ( is => 'rw', isa => 'Str', default  => 'ensemble' );
my $SVM;
my $POSKEY="/home/green/tectomt/treex/lib/Treex/Tool/ML/SVM/poskey";
my $MODELKEY="/home/green/tectomt/treex/lib/Treex/Tool/ML/SVM/modelkey";
my $ENSEMBLE;
my %poshash;
my %modelhash;
#must pass into this class a string 'trees' with the format parser#weight~parser#weight  for as many parsers as you want used out of the a-trees
sub BUILD {
  my ($self) = @_;
    $SVM = Treex::Tool::ML::SVM::SVM->new();
    $ENSEMBLE = Treex::Tool::Parser::Ensemble::Ensemble->new();
    $ENSEMBLE->clear_edges();
    open POS, "$POSKEY" or die $!;
    my @lines = <POS>;
    foreach my $line (@lines){
    my @tokens = split ("\t",$line);
    $poshash{$tokens[0]}=$tokens[1];
    }
    close (POS);
    
    
    open MODEL, "$MODELKEY" or die $!;
    @lines = <MODEL>;
    foreach my $line (@lines){
      my @tokens = split ("\t",$line);
      $modelhash{$tokens[0]}=$tokens[1];
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
  my @todo = $tree_root->get_descendants( { ordered => 1 } );    
  
  my $pos=0;
  my $sentence_length=scalar @todo;
  my $quartile=0;
  
  my $i=0;
  foreach my $node (@todo){
    
    if(exists $poshash{$node->tag}){
      $pos=$poshash{$node->tag};
    }
    else{
      $pos=0;
    }

  $quartile=find_bucket($i,$sentence_length);
#   print $pos; 
#   print "\t" ;
#   print $quartile ;
#   print "\t" ;
#   print $sentence_length; 
#   print "\n";
  
  my $dstest = new Algorithm::SVM::DataSet(Label => "predict",
					   Data  => [$pos,$quartile,$sentence_length]);

 my $predictedModel=  $SVM->predict($dstest);
 
 my $tree_root = $bundle->get_tree( $self->language, 'a', $modelhash{chomp($predictedModel)} );  
 my @modelNodes = $tree_root->get_descendants( { ordered => 1 } );  
 $ENSEMBLE->add_edge( $modelNodes[$i]->parent->ord, $node->ord, 1 );

  $i++;
  }
  make_graph( $self, $bundle );
}

sub make_graph {
  my ( $self, $bundle ) = @_;
  my $mst = $ENSEMBLE->get_mst();
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
