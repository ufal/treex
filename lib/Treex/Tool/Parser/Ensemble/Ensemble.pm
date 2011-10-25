package Treex::Tool::Parser::Ensemble::Ensemble;
use Graph::Directed;

use Graph::ChuLiuEdmonds;
use Moose;
		  
my %edges=();
my $N=0;
sub BUILD {
  my ( $self, $params ) = @_;
}

sub add_edge {
  my ( $self, $node, $parent ) = @_;
  if(exists $edges{$node}{$parent}){
    $edges{$node}{$parent}= $edges{$node}{$parent}+1;
    }
    else{
      $edges{$node}{$parent}=1;
    }
}

sub clear_edges{
  my ($self) = @_;
  
  %edges=();
}

sub print_edge_matrix{
  my $j=0;
  my $i=0;
  my ($self) = @_;
  #print double edge hash
  for($i=1;$i<$N;$i++){
    for($j=1;$j<$N;$j++){
      if(exists $edges{$i}{$j} ){
    print $edges{$i}{$j};
      }
      else{
      print "0";
      }
    }
    print "\n";
  }
  }
  
sub set_n{
  my ($self,$n) = @_;
  $N=$n+1;
}
sub get_mst{
  
  my $graph = Graph::Directed->new;   
my $j=1;
my $i=1;
my ($self) = @_;

#print double edge hash
my $graph = Graph::Directed->new(
vertices => [ ( 1 .. $N ) ]
);

for($i=1;$i<$N;$i++){
  for($j=1;$j<$N;$j++){
    if(exists $edges{$i}{$j} ){
   $graph->add_weighted_edge($i,$j,$N-$edges{$i}{$j});   
 #  print "$i->$j\n";
    }
    else{
     if($i != $j){
     # $graph->add_weighted_edge($i,$j,$N); 
     }
     }
  } 
}  
print "graph= $graph \n";
my $mstg = $graph->MST_ChuLiuEdmonds($graph);
#  print "The graph is $mstg\n" ; 
return $mstg;
}
1;
__END__
	      
	      