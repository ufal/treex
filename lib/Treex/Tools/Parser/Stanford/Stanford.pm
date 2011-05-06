package Treex::Tools::Parser::Stanford::Stanford;

use Moose;
use MooseX::FollowPBP;
use Treex::Core::Log;
use Treex::Tools::Parser::Stanford::Node;
use ProcessUtils;
use IPC::Open2;
use IPC::Open3;
use IO::Handle;
use Treex::Core::Common;
#to be changed

my $tmp_input = 'test';

my $bindir = "/home/green/tectomt/personal/green/tools/stanford-parser-2010-11-30";
my $tmp_file = "$bindir/temporary.txt";
my $command = "java -cp stanford-parser.jar edu.stanford.nlp.parser.lexparser.LexicalizedParser -sentences newline englishPCFG.ser.gz ";
my @sentences=();
my @results;

sub BUILD {
    my ( $self ) = @_;
    log_fatal "Missing $bindir\n" if !-d $bindir;


	my $runparser_command = "$command $tmp_file";
  my ( $reader, $writer, $pid ) = ProcessUtils::bipipe("cd $bindir; $runparser_command ");
    $self->{tntreader} = $reader;
    $self->{tntwriter} = $writer;
    $self->{tntpid}    = $pid;

    bless $self;
}



sub string_output {
 
    my ($self,@tokens) = @_;

    # creating a temporary file - parser input
    
  #  log_info 'Storing the sentence into temporary file: $tmp_file';



 #print (join ' ',@tokens);
 my $string = (join ' ',@tokens);
  $string =~ s/''/"/g;
  $string =~ s/``/"/g;
  chomp($string);
    open my $INPUT, '>:utf8', $tmp_file or log_fatal $!;
    print $INPUT $string;
    close $INPUT;

 
    my $writer = $self->{tntwriter};
       print $writer $tmp_file ;
    my $reader = $self->{tntreader};
    
    my $out_string="";
    my $start="false";
    while (<$reader>){
    chomp($_);
    #print $_;
    if($_=~"ROOT"){
    $start="true";
    #print $_;
    }
    if($start eq "true"){
   # print $_;
    $out_string.=$_;
    
    }
     }

return $out_string;







}

sub parse {
    my ($self,@tokens_rf) = @_;
_make_phrase_structure(string_output($self,@tokens_rf)); 

}


sub _make_phrase_structure {
    my ($parser_output) = @_;
	
 
 #print $parser_output;
 my @tree = ();
    my @final_tree=();

    my @tags = split (" ", $parser_output);

    foreach my $tag (@tags) {

        # opening a node
        if ( $tag =~ /[\(\[\{]/ ) {
            substr($tag,index($tag, "\("),1,"");
            my $node=Treex::Tools::Parser::Stanford::Node->new(term=>$tag);
            push (@tree, $node);
         #   print "added $tag\n";
	}

        # closing the node
        elsif ( $tag =~ /[\)\]\}]/ ) {
            my $parentCount=0;
            while ($tag=~ /[\)\]\}]/) {
                $parentCount++;
                substr($tag,index($tag, "\)"),1,"");
            }
            my $node=Treex::Tools::Parser::Stanford::Node->new(term=>$tag);

	    push (@tree, $node);        
	    push(@final_tree,$node);

            my $i=0;
	    
            while ($i<$parentCount) {
	         $node= pop(@tree); 
		       
             my  $parent= pop(@tree);	
	                
                push(@final_tree,$node);
                $parent->add_child($node);	
#print "Added ".$node->get_type()." to ".$parent->get_type()." \n";	
		push (@tree, $parent);          
                $i++;
            }
		#add link to parent top branch) nodes where the parent is comprised of multiple sub branches
		$node= pop(@tree); 
		 push(@final_tree,$node);
		my  $topBranch = pop(@tree);
		if($topBranch){
		$topBranch->add_child($node);	 
#		print "Added ".$node->get_type()." to ".$topBranch->get_type()." \n";
		push(@tree,$topBranch);
		}
        }
      
    }



    return pop @final_tree;

}




1;

__END__


