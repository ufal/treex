package Treex::Tool::Parser::Ensemble::Ensemble;

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
	      #print $node."\t"."$parent"."\n";
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
		for($i=0;$i<$N;$i++){
		  for($j=0;$j<$N;$j++){
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
	      $N=$n;
	      }
	      1;
	      __END__
	      
	      