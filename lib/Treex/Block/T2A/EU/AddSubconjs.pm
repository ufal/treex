package Treex::Block::T2A::EU::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubconjs';

use utf8;

override 'process_tnode' => sub {
   my ( $self, $tnode ) = @_;
   $self->preprocess($tnode);
   my $subconj_forms_str = $self->get_subconj_forms($tnode->formeme);  
   my $anode = $tnode->get_lex_anode();

   # Skip weird t-nodes with no lex_anode and nodes with no subconjs to add
   return if (!defined $anode or !$subconj_forms_str);

   # Occasionally there may be more than one subcons (e.g)
   my @erl_tokens = split /_/, $subconj_forms_str;
   my $erl_string="";
   my @subconj_nodes;
   
   # There can be two types of data in prep_forms:
   #   Between brackets: erl
   #   Otherwise: other words (i.e: egin arren)
   
   # Get and store erl and cases
   foreach (@erl_tokens){
       
       # Retrieve the verb form
       if (substr($_,0,1) ne "["){
	   push(@subconj_nodes, $_);
       }
       else{ # Retrieve relation info
	   my $len = length($_);
	   $erl_string.="_" if($erl_string ne "");
	   $erl_string.=substr($_, 1, $len-2);
       }
       
   }
   
   # Make the first element of the array head of the subconjs
   my $subconj_head;
   if($subconj_nodes[0]){
       $subconj_head = $anode->get_parent()->create_child({lemma=>$subconj_nodes[0], form=>$subconj_nodes[0]});
       $subconj_head->shift_after_subtree($anode); # Give the head the corresponding order

       shift(@subconj_nodes); #remove the first element of the array

       # Hang the rest of the nodes from the head
       foreach (@subconj_nodes){
	   my $subconj_node = $subconj_head->create_child({lemma=>$_, form=>$_});
	   $subconj_node->shift_after_node($subconj_head); # Give the nodes the proper order
       }
       
       # Hang the anode from the subconj head
       $anode->set_parent($subconj_head) if($subconj_head && ( $anode->get_parent()->id ne $subconj_head->id) );
   }

   # Store the relation info in the wild_dump
   $anode->wild->{erl} = $erl_string if($erl_string ne "");
   
   # Language-specific stuff to go here
   $self->postprocess($tnode, $anode, $subconj_forms_str, \@subconj_nodes);

   return;
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddSubconjs

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.
In Spanish, it seems adverbs may have prepositions as well (e.g. "por allí").

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
