package Treex::Block::W2A::EU::FixModalVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my @MODAL = ("nahi", "ahal", "ezin", "behar");
#my @MODAL = ("nahi", "gura", "gogo", "ahal", "ezin", "behar", "ari");
my $MAXDISTANCE = 3;# Max distance between the modal and the main verb


#Function to hang all the children of a node from the head
sub rehang_children{
    my ($parent, $head) = @_;

    my @children = $parent->get_children;
    for (my $i=0; $i<=$#children; $i++){
	$children[$i]->set_parent($head);
    }

}

sub process_anode {

    # TODO: modal+ukan+izan type of complex structures. i.e: "Ezin izango duzu"
    # TODO: modal+izanez+gero. i.e: "nahi izanez gero"
    # A possible way to fix this would be to consider the verbs with the lemma izan,ukan,edin or ezan as aux and accept more than one aux verb.

    my ($self, $anode) = @_;  

    if (grep {$anode->lemma eq $_} @MODAL) { # Only get anodes with a modal

	my $parent = $anode->get_parent();
	return 1 if ($parent->is_root);

	# Get the position of the modal in the sentence
	my $ord = $anode->ord; 
  
	# Get the verbs among the descendants of the parent. Parent is added too
	my @verbNodes = grep {$_->is_verb} $parent->get_descendants({ordered=>1, add_self=>1});

       	# Store the verbs in a hash table
	my %hashNode; # Hash table to store all the verbs among the nodes to be analyzed 
	$hashNode{$_->ord}=$_ for (@verbNodes);
	   
	my $indV; # Index of the main verb in the hash table
	my $indAuxV; # Index of the aux Verb in the hash table

	# Get the hash indexes of the closest main and auxiliary verb from the modal, if they exist.
       	while (my($key,$node)=each(%hashNode)){
	    # The distance between the modal and the verbs must be in the range (0,MAXDISTANCE]
	    if ( ($node->ord != $ord) && (abs($ord - $node->ord) <= $MAXDISTANCE ) ){  
		# Get the index of the colsest aux verb from the modal
	        if($node->iset->person){  
		    $indAuxV=$key if (!defined($indAuxV) || ( abs($ord - $node->ord) < abs($ord - $hashNode{$indAuxV}->ord)));
		}
		else{ # Get the index of the closest base form verb to the modal
		    $indV=$key if(!defined($indV) ||( abs($ord - $node->ord) < abs($ord-$hashNode{$indV}->ord)));
		}
	    }
      	}#end while

	# The head node will be either the modal or the main verb
	my $headNode; 

	$headNode=$hashNode{$indV} if( defined($indV) && defined($indAuxV));
	$headNode=$anode if(!defined($indV) && defined($indAuxV));

	if(defined($headNode)){

	    # Avoid the cycle resulting from tryng to rehang the headNode from himself.
	    if ($headNode->id ne $parent->get_parent()->id){

		# Hang the head node on top
		$headNode->set_parent($parent->get_parent());
		
		# Hang the aux verb (and its children from the head node (if there is any)
		if (defined($indAuxV)){
		    # Rehang the aux verb node
		    $hashNode{$indAuxV}->set_parent($headNode);
		    $hashNode{$indAuxV}->set_afun('AuxV');
		    
		    # Regang the aux verb's children     
		    rehang_children($hashNode{$indAuxV}, $headNode);
		}
	    
		# Rehang the modal's children from the head if the head isn't the modal itself
		if ($anode->id ne $headNode->id){

		    $anode->set_afun('AuxV');
		    
		    # Regang the modal's children  
		    rehang_children($anode, $headNode);
		}
	    }
	}
	
    }

    return 1;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EU::

=head1 DESCRIPTION

Fix the analysis of several modal verbs

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright Â© 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
