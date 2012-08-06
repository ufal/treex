
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
	my %unique_document_atree; #for keeping the track of all the atrees under unique document name 
	
	
	#Obtain the location of the treex files
	my $document_path = $document->path;
	#Obtain Annotation info
	
	#Determine Source Language
	if(!defined($document->wild->{annotation}{source}{language})) { print STDERR "ERROR no sourcelanguage defined\n"; exit;}
	my $source_language = $document->wild->{annotation}{source}{language};
	my %folder_set; #maintains a set of unique folders for each study
	
	
	
	################Process bundles##########
	foreach my $bundle (@bundles){
		my @zones = $bundle->get_all_zones;
			
		foreach my $zone (@zones){
			
			
			my $zone_selector = $zone->selector;
			my $a_tree = $zone->get_atree;
			#the following hash groups trees by selectors
			push(@{$unique_document_atree{$zone_selector}},$a_tree);
						
		}
	}
	
	foreach my $selector (keys %unique_document_atree){
		unless ($selector eq "source"){
			
			#sort the atrees according to the sentence number.
			my ($filename,$foldername) = format_file_name($self,$selector,".tgt");
			my $output_folder = $document_path."../".$foldername."/Alignment-II";
			
			unless(-d $output_folder){
	    			
	    			mkdir $output_folder or die $!;
	    			print STDERR "TREEX-INFO:	directory for writing the xml files created at $output_folder"."\n";
			}
					
			$folder_set{$output_folder} = 1;
			my $full_path = $output_folder."/".$filename;
			my @atree_list= @{$unique_document_atree{$selector}};
			
			my %annotation_info ;
			
			if(defined $document->wild->{annotation}{$selector}){
				%annotation_info = %{$document->wild->{annotation}{$selector}};
			}
			else{
				print STDERR "Warning:: No annotation info for selector $selector."
			}
			#Synth the target files and write in the respective directory
			write_to_file($self,$full_path,\@atree_list,\%annotation_info);
			
			my $target_language = "";
			unless (defined $document->wild->{annotation}{$selector}{language}){
				die "Couldn't obtain target language for selector $selector. Failed to gt back atag file."
			}
			$target_language = $document->wild->{annotation}{$selector}{language};
			#Now form the atag files and copy them in the same directory
			write_atag_files($self,$full_path,$source_language,$target_language,\@atree_list);
		}	
	}
	my @src_atree_list = @{$unique_document_atree{source}};
	
	#Generate and Copy the source file as many as the target files
	foreach my $folder (keys %folder_set){ 
		my $full_path = $folder."/source.src";
		my %annotation_info;
		
		if(defined $document->wild->{annotation}{source}){
			%annotation_info = %{$document->wild->{annotation}{source}};
		}
		else{
			print STDERR "Warning:: No annotation info for selector source."
		}
			
			
		#put one src file in each document under the name source.src
		write_to_file($self,$full_path,\@src_atree_list,\%annotation_info);
		#copy source.src as many as the number of tgt files and deletes source.src
		copy_src_files($self,$folder);
	}
	
	
}


sub write_atag_files{
	my ($self,$full_path,$source_language,$target_language,$a_tree_ref) = @_;	

	#remove extention and attach atag
	$full_path=~ s/\....$//;
	my $atag_filename = $full_path.".atag"; 
	
	my $base_name = (fileparse($full_path, qr/\.[^.]*$/))[0];
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

	my @a_tree_list = @{$a_tree_ref};	
	for my $a_tree (@a_tree_list){
 
		my @ordered_nodes = $a_tree->get_descendants({ordered=>1});
		
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
	my ($self,$full_path,$a_tree_ref,$annotation_info) = @_;
	
	my $writable_document = XML::LibXML::Document->new( '1.0', 'utf-8' );
	my $root = $writable_document->createElement ('Text');
	
	if(defined $annotation_info){
		my %list = %{$annotation_info};
		foreach my $key (sort keys %list){
			unless ($key eq "fileName"){
				$root->addChild ($writable_document->createAttribute ( $key =>$list{$key}) );
			}
		}
	}
	my @a_tree_list = @{$a_tree_ref};
	for my $a_tree (@a_tree_list){
 
		my @ordered_nodes = $a_tree->get_descendants({ordered=>1});
		
		for my $node (@ordered_nodes){
			my $word = $writable_document->createElement("W");
			my %attribs = %{$node->wild};
			
			#append the attributes
			$word->addChild ($writable_document->createAttribute ( id =>$attribs{id}) );
			$word->addChild ($writable_document->createAttribute ( cur =>$attribs{cur}) );
			while ((my $key,my $value) = each %attribs)
			{
  				unless ($key eq "tok" or $key eq "linenumber" or $key eq "sent_number" or $key eq "cur" or $key eq "id"){
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
	open FILE,">", $full_path or die $!; 
	print FILE $writable_string; 
	close FILE;
	
}
sub copy_src_files{
	
	#Copies source files as many as the newly created tgt files
	my($self,$output_path)=@_;	
	opendir (DIR, $output_path) or die $!;
	my $src_path = $output_path."/source.src";
	while (my $file = readdir(DIR)) {
        unless (-d $file){
                my $path= abs_path($file);
                my @ext = (fileparse($path, qr/\.[^.]*$/));
                if($ext[2] eq ".tgt"){
                	
                	my $tgt_path = $output_path."/".$ext[0].".src";
                	unless(-e $tgt_path){
                		#if src files have already been created, no need to create
                		copy($src_path,$tgt_path) or die "Copy failed: $!";	
                	}
                	
                }
                
                
        }
    }
    #delete source.src
    unlink($src_path);
    closedir(DIR);
	
}
sub format_file_name{
		
		#Obtains the folder and file name from the selector.
		
        my ($self,$filename,$type)=@_;
        my $folder_name = "";
        $filename =~ /^([A-Z]+[0-9]+)([A-Z]+[0-9]+)([A-Z]+[0-9]+)$/;
        unless (defined $1){die "Selector couldn't be parsed. Aborting....";}
        $folder_name = $1;
        $filename = $2."_".$3.$type;
       ($filename,$folder_name);
}
1;

'
This program extracts source, target and alignment files from treex

Written by : Abhijit Mishra

It generates src,tgt and atag files from treex files. The file names and study directories are obtained from the node selectors. 
At first the tgt and atag files are written back. Then it generates source.src and puts in each study directory contributing to the treex file.
It, then , copies the src file as many as the newly generated tgt files and deletes the source.src. 
'


