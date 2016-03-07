
package Treex::Block::Misc::Translog::RemakeWildZones;

use utf8;
use Moose;
use Treex::Core::Common;
use Data::Dumper; $Data::Dumper::Indent = 1;
use diagnostics;
use File::Basename;
use File::Copy;

extends 'Treex::Core::Block';

sub process_document {
	my ($self, $document) = @_;
	my (@bundles) = $document->get_bundles;
	my $document_path = $document->full_filename;
	
	foreach my $bundle (@bundles){
		
		my @zones = $bundle->get_all_zones;
		foreach my $zone (@zones){
			my $a_tree = $zone->get_atree;
			my @nodes = $a_tree->get_descendants;
			my %node_out_ref_values;		
			foreach my $node (@nodes){
				
				my $node_id = $node->id;
				######################################################################################################
				if(defined $node->tag){
					my $tag = $node->tag;
					
					if (defined $node->wild->{pos}){
						my $wild_pos = $node->wild->{pos};
						unless($wild_pos eq $tag){
							
							$node->{wild}{pos} = $tag;
							print  "CHANGE:\tPOS tag changed from $wild_pos to $tag for the node: $node_id \n";
						}
					}
					else{
						$node->{wild}{pos}=$tag;
						print  "CHANGE:\tPOS tag added to wild zone for the node: $node_id \n"; 
					}
						
				}
				#####################################################################################################
				if (defined $node->lemma){
					my $lemma = $node->lemma;
					if (defined $node->wild->{lemma}){
						my $wild_lemma = $node->wild->{lemma};
						unless($wild_lemma eq $lemma){
							$node->{wild}->{lemma}=$lemma;
							print "CHANGE:\tLemma changed from $wild_lemma to $lemma for the node: $node_id \n";
						}
					}
					else{
						$node->{wild}->{lemma}=$lemma;
						print "CHANGE:\tPOS tag added to wild zone for the node: $node_id \n"; 
					}	
				}
				######################################################################################################
				
				my $parent = $node->get_parent;
				if ($parent and $parent->ord != 0){
					my $deprel="";
					my %in_value;
					my $in;
					my $diff = int($parent->wild->{id})-int($node->wild->{id}); 
					if (defined $node->{conll}->{deprel} )
					{
						$deprel = $node->{conll}->{deprel};
						$in_value{"$diff:$deprel"}=1;
						
					}
					my ($nodes_rf,$typ_ref) = $node->get_directed_aligned_nodes();
					
					if (defined $nodes_rf){
						my @ref_nodes = @{$nodes_rf};
						my @ref = @{$typ_ref};
						my $i=0;
						foreach my $ref_node (@ref_nodes){
							
							if (not $ref[$i] eq "alignment"){
								$diff = int($ref_node->wild->{id})-int($node->wild->{id});
								$in_value{"$diff:$ref[$i]"}=1;
								my $mdiff = -$diff;
								$node_out_ref_values{$ref_node->id}{"$mdiff:$ref[$i]"}=1;
								#print "src ".$ref_node->id." $mdiff:$ref[$i]\n";
							}
							$i++;
							
						}
					}
					my $in_string ="";
					if (%in_value){
						$in_string = prepare_string_from_hash($self,\%in_value);
					}
					
					if(defined $node->wild->{in}){
						$in = $node->wild->{in};
					}
					
					unless (compare_out_strings($in_string,$in)==1){
							$node->{wild}->{in} = $in_string;
						
						print "CHANGE:\tIN value in the wild Zone changed from $in to $in_string for node: $node_id \n";
					}			
					
					
				}
				
			}	
			
				#######################################################################################################
				
				
			my @out_nodes=$a_tree->get_descendants;
			foreach my $node (@out_nodes){
				my $node_id = $node->id;
				my @children = $node->get_children;
				if (@children){
					
					my $out="";
					my %out_value;
					
					foreach my $child (@children){
						my $deprel="";
						my $diff = int($child->wild->{id})-int($node->wild->{id});
						if (defined $child->{conll}->{deprel} )
						{
							$deprel=$child->{conll}->{deprel};
							$out_value {"$diff:$deprel"}=1;
						}
						
					}
					if (defined  $node_out_ref_values{$node_id}){
							
							my %out_ref = %{$node_out_ref_values{$node_id}};
							foreach my $out_key (keys %out_ref){
									
								$out_value {$out_key}=1;
							}
					}
					
					my $out_string = "";
					if (%out_value){
						$out_string = prepare_string_from_hash($self,\%out_value);	
					}
					
					
					
					if (defined $node->wild->{out}){
						$out = $node->wild->{out};
						
							
					}
					
					if (compare_out_strings($out_string,$out)==0){
									
							unless ($out_string eq ""){
								$node->{wild}->{out} = $out_string;
								print "CHANGE:\tOUT value in the wild Zone changed from $out to $out_string for node: $node_id \n"
							}
					}
									
						
				}
				
								
				
			}	
		}
	}
		
}
sub prepare_string_from_hash{
	my ($self,$hash_value) = @_;
	my %my_hash=%{$hash_value};
	my $string = "";
	foreach my $key (sort keys(%my_hash)){
		$string = $string."$key|";
	}
	$string = substr($string,0,-1);
	$string;
}
sub compare_out_strings{
	my($out1,$out2)=@_;
	
	if ($out1 eq $out2){return 1;}
	my @arr1 = sort (split("\\|",$out1));
	my @arr2 = sort (split("\\|",$out2));
	my $str1 = join('', @arr1);
	my $str2 =  join('', @arr2);
	if ($str1 eq $str2){
		return 1;
	}
	else{
		return 0;
	}
	
	
}

1;
	
	
	
			
		