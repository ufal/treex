# This program extracts source, target and alignment files from treex

package Treex::Block::Misc::Translog::Treex2Alignment;

use utf8;
use Moose;
use Treex::Core::Common;
use Data::Dumper; $Data::Dumper::Indent = 1;
use diagnostics;
use File::Basename;
use File::Copy;
use Cwd 'abs_path';

extends 'Treex::Core::Block';

sub process_document {
	
	my ($self, $document) = @_;
	my (@bundles) = $document->get_bundles;
	my %unique_document_atree; 
	
	
	#Obtain the location of the treex files
	my $document_path = $document->path;
	
	#Determine Source Language
	if(!defined($document->wild->{annotation}{sourceLanguage}{language})) { print STDERR "ERROR no sourcelanguage defined\n"; exit;}
	my $source_language = $document->wild->{annotation}{sourceLanguage}{language};
	my %folder_set;
	my $source_document_info = "";
	
	################Process bundles##########
	foreach my $bundle (@bundles){
		my @zones = $bundle->get_all_zones;
			
		foreach my $zone (@zones){
			
			my $zone_language = $zone->language;
			my $zone_selector = $zone->selector;
			my $filename = "";
			my $foldername = "";
			my $output_path= "";
			my $document_info = ""; #containg path and language information
			
			if ($zone_language eq $source_language){
				
				#format_file_name returns the file and folder name from the selector
				($filename,$foldername) = format_file_name($self,$zone_selector,"src");	
				$document_info = $filename;
				$source_document_info = $filename."@@".$source_language;
				
			}
			else{
				($filename,$foldername) = format_file_name($self,$zone_selector,"tgt");
				$output_path = $document_path."../".$foldername."/Alignment-II";
			
				#maintaining a list of folders.
				$folder_set{$output_path} = 1;
			
				unless(-d $output_path){
	    			
	    			mkdir $output_path or die $!;
	    			print STDERR "TREEX-INFO:	directory for writing the xml files created at $output_path"."\n";
				}
			
				$document_info = $output_path ."/". $filename;
			}
			my $a_tree = $zone->get_atree;
			
			#Appending language informarion in filename
			$document_info = $document_info . "@@" . $zone_language;
			
			#the following hash groups trees by filenames
				
			push(@{$unique_document_atree{$document_info}},$a_tree);
						
		}
	}
	################
	#remove redundancy
	
	foreach my $document_info (keys %unique_document_atree){
		unless ($source_document_info eq $document_info){
			#sort the atrees according to the sentence number.
			my @atree_list= @{$unique_document_atree{$document_info}};
			
			
			
			
			
			#Form the target files and write in the respective directory
			write_to_file($self,$document_info,@atree_list);
			
			#Now form the atag files and copy them in the same directory
			write_atag_files($self,$document_info,$source_language,@atree_list);
		}	
	}
	my @src_atree_list = @{$unique_document_atree{$source_document_info}};
	
	#Generate and Copy the source file as many as the target files
	foreach my $folder (keys %folder_set){ 
		my $document_info = $folder."/". $source_document_info;
		
		write_to_file($self,$document_info,@src_atree_list);
		copy_src_files($self,$source_document_info,$folder);
	}
	
	
}

sub order_nodes{
	my ($self,@nodes) = @_;
	my %temp_hash_for_keeping_nodes;
	my @ordered_nodes;
	
	foreach my $node (@nodes){
		 my $key=int($node->ord);
	 
		 
		 $temp_hash_for_keeping_nodes{$key} = $node;
	}	
	
	for my $key (sort { $a <=> $b } keys %temp_hash_for_keeping_nodes){
		 
		push (@ordered_nodes,$temp_hash_for_keeping_nodes{$key});
	}
	@ordered_nodes;
}
sub write_atag_files{
	my ($self,$document_info,$source_language,@a_tree_list) = @_;
	my @info = split('@@', $document_info);
	
	#obtain language info and file name
	my $filename  = $info[0];
	my $target_language = $info[1];
	
	#remove extention and attach atag
	$filename=~ s/\....$//;
	
	my $atag_filename = $filename.".atag"; 
	
	my $base_name = (fileparse($filename, qr/\.[^.]*$/))[0];
	my $src_href = $base_name.".src";
	my $tgt_href = $base_name.".tgt";
	
	my $atag_writable_document = XML::LibXML::Document->new( '1.0', 'utf-8' );
	my $root = $atag_writable_document->createElement ('DTAGalign');
	$root->addChild ($atag_writable_document->createAttribute (source => $source_language));
	$root->addChild ($atag_writable_document->createAttribute (target => $target_language));
	
	#create source meta info
	my $alignFile = $atag_writable_document->createElement("alignFile");
	$alignFile->addChild ($atag_writable_document->createAttribute (href => $src_href));
	$alignFile->addChild ($atag_writable_document->createAttribute (key => "a"));
	$alignFile->addChild ($atag_writable_document->createAttribute (sign => ""));
	$root->addChild($alignFile);
	
	#create target meta info
	$alignFile = $atag_writable_document->createElement("alignFile");
	$alignFile->addChild ($atag_writable_document->createAttribute (href => $tgt_href));
	$alignFile->addChild ($atag_writable_document->createAttribute (key => "b"));
	$alignFile->addChild ($atag_writable_document->createAttribute (sign => ""));
	$root->addChild($alignFile);
	
	for my $a_tree (@a_tree_list){
 
		my @nodes = $a_tree->get_descendants;
		
		#get the sorted node list
		my @ordered_nodes =  order_nodes ($self,@nodes);
		
		for my $node (@ordered_nodes){
			my $in = "b".$node->ord;
			my $insign = $node->form;
			#get alignment information
			my @align_nodes = $node->get_aligned_nodes_of_type("alignment");
			if (@align_nodes){
				foreach my $align_node(@align_nodes){
					my $out = "a".$align_node->ord;
					my $outsign = $align_node->form;
					my $align_xml_node = $atag_writable_document->createElement("align");
					$align_xml_node->addChild ($atag_writable_document->createAttribute (in => $in));
					$align_xml_node->addChild ($atag_writable_document->createAttribute (insign => $insign));
					$align_xml_node->addChild ($atag_writable_document->createAttribute (out => $out));
					$align_xml_node->addChild ($atag_writable_document->createAttribute (outsign => $outsign));
					$root->addChild($align_xml_node);
				}
			}	
		}
	}
	$atag_writable_document->setDocumentElement($root);
	my $atag_writable_string = $atag_writable_document->toString(1);
	open FILE,">", $atag_filename or die $!; 
	print FILE $atag_writable_string; 
	close FILE;
	
}
sub write_to_file{
	my ($self,$document_info,@a_tree_list) = @_;
	my @info = split('@@', $document_info);
	my $filename  = $info[0];
	my $language = $info[1];
	
	my $writable_document = XML::LibXML::Document->new( '1.0', 'utf-8' );
	my $root = $writable_document->createElement ('Text');
	$root->addChild ($writable_document->createAttribute (language => $language));
	#print "doc::".$document_info." atrees::".scalar(@a_tree_list)."\n";
	for my $a_tree (@a_tree_list){
 
		my @nodes = $a_tree->get_descendants;
			#print "	nodes::".scalar(@nodes)."\n";
		#get the sorted node list
		my @ordered_nodes =  order_nodes ($self,@nodes);
			#print "	ordered nodes::".scalar(@ordered_nodes)."\n";
		for my $node (@ordered_nodes){
			my $word = $writable_document->createElement("W");
			my %attribs = %{$node->wild};
			
			#append the attributes
			while ((my $key,my $value) = each %attribs)
			{
  				unless ($key eq "tok" or $key eq "linenumber" or $key eq "sent_number"){
  					$word->addChild ($writable_document->createAttribute ( $key => $value) );
  					
  				}
			}
			
			#Create the textnode
			my $text = $node->form; 
			$word->addChild($writable_document->createTextNode($text));
			
			$root->addChild($word);
			
		}
		
		
	} 
	$writable_document->setDocumentElement($root);
	my $writable_string = $writable_document->toString(1);
	open FILE,">", $filename or die $!; 
	print FILE $writable_string; 
	close FILE;
	
}
sub copy_src_files{
	my($self,$src_document_info,$output_path)=@_;
	
	my @info = split('@@', $src_document_info);
	my $src_filename  = $info[0];
	my $src_path = $output_path."/".$src_filename;
	opendir (DIR, $output_path) or die $!;
	while (my $file = readdir(DIR)) {
        unless (-d $file){
                my $path= abs_path($file);
                my @ext = (fileparse($path, qr/\.[^.]*$/));
                if($ext[2] eq ".tgt"){
                	
                	my $tgt_path = $output_path."/".$ext[0].".src";
                	copy($src_path,$tgt_path) or die "Copy failed: $!";
                }
                
                
        }
    }
    #delete source.src
    unlink($src_path);
    closedir(DIR);
	
	
}
sub format_file_name{
        my ($self,$filename,$type)=@_;
        my $folder_name = $filename;
        $filename =~ s/[A-Z]+[0-9]+//;
        $folder_name =~ s/$filename// ;

        $filename=~ s/([A-Z]+[0-9]+)/$1_/;
        $filename = $filename.".$type";
        ($filename,$folder_name);
}

