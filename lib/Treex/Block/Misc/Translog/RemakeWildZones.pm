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
			foreach my $node (@nodes){
				
				my $node_id = $node->id;
				if(defined $node->tag){
					my $tag = $node->tag;
					
					if (defined $node->wild->{pos}){
						my $wild_pos = $node->wild->{pos};
						unless($wild_pos eq $tag){
							
							$node->{wild}{pos} = $tag;
							print  "POS tag changed from $wild_pos to $tag for the node: $node_id \n";
						}
					}
					else{
						$node->{wild}{pos}=$tag;
						print  "POS tag added to wild zone for the node: $node_id \n"; 
					}
						
				}
				if (defined $node->lemma){
					my $lemma = $node->lemma;
					if (defined $node->wild->{lemma}){
						my $wild_lemma = $node->wild->{lemma};
						unless($wild_lemma eq $lemma){
							$node->{wild}->{lemma}=$lemma;
							print  "Lemma changed from $wild_lemma to $lemma for the node: $node_id \n";
						}
					}
					else{
						$node->{wild}->{lemma}=$lemma;
						print  "POS tag added to wild zone for the node: $node_id \n"; 
					}	
				}
				
				
				my $parent = $node->get_parent;
				if ($parent and $parent->ord != 0){
					my $deprel="";
					if (defined $node->{conll}->{deprel} ){$deprel = $node->{conll}->{deprel};}
					my $in_value = (int($parent->wild->{id})-int($node->wild->{id})).":".$deprel;
					
					
					if(defined $node->wild->{in}){
						my $in = $node->wild->{in};
						unless ($in_value eq $in){
							$node->{wild}->{in} = $in_value;
							
							#print  "IN value in the wild Zone changed from $in to $in_value for node: $node_id \n";
						}			
					}
					else{
												
							$node->{wild}->{in} = $in_value;
							#print  "IN value added to wild zone for the node $node_id \n";	
						}
				}
				
					
				my @children = $node->get_children;
				if (@children){
					if (defined $node->wild->{out}){
						my $out = $node->wild->{out};
						my $out_value = "" ;
						
						foreach my $child (@children){
							my $deprel="";
							if (defined $child->{conll}->{deprel} ){$deprel=$child->{conll}->{deprel};}
							$out_value = $out_value.(int($child->wild->{id})-int($node->wild->{id})).":".$deprel."|";
						}
						$out_value = substr($out_value, 0, -1);
						unless($out_value eq $out){
							$node->{wild}->{out}=$out_value;
							#print  "OUT value in the wild Zone changed from $out to $out_value for node: $node_id \n"
						}
							
					}
					else{
						my $out_value = "" ;
						
						foreach my $child (@children){
							my $deprel="";
							if (defined $child->{conll}->{deprel} ){$deprel=$child->{conll}->{deprel};}
							$out_value = $out_value.(int($child->wild->{id})-int($node->wild->{id})).":".$deprel."|";
						}
						$out_value = substr($out_value, 0, -1);
						
						$node->{wild}->{out}=$out_value;
						#print  "OUT value added to wild zone for the node $node_id \n";
					}
					
				}
				else{
					$node->{wild}{out} = "";
					#print "Deleted OUT value for the node $node_id";
				}
								
				
			}	
		}
	}
		
}
sub prepare_string_from_hash{
	my ($self,%hash_value) = @_;
	my $string = "";
	foreach my $key (sort {$a <=> $b} keys(%hash_value)){
		$string = $string."$key:$hash_value{$key}|";
	}
	$string = substr($string,0,-1);
	$string;
}

sub get_ref_nodes{
	my ($self,$node) = @_;
	my ($nodes_rf,$typ_ref) = $node->get_aligned_nodes();
	my @no
				
	if (defined $nodes_rf){
		my @n = @{$nodes_rf};
		my @r = @{$typ_ref};
	my $i=0;
	foreach my $n (@n){
		
		if (!$r[$i] eq "alignment"){
		
		print "\n".$node->id." ".$n->id." ".$r[$i]."\n";
		}
		$i++;
		
	}
	}
	else{
		if(defined $node->{alignment}){;#{"counterpart.rf"}){
			#print $node->{alignment};
		}
	}
	
}
1;
	
	
	
			
		
