package Treex::Tools::Phrase2Dep::Pennconverter;
use Moose;
use MooseX::FollowPBP;
use Treex::Core::Log;
use File::Java;

use ProcessUtils;

#to be changed

my @all_javas;    # PIDs of java processes
sub BUILD {
    my ( $self ) = @_;
    my $bindir = "$ENV{TMT_ROOT}libs/other/Parser/Pennconverter";
    die "Missing $bindir\n" if !-d $bindir;


    my $javabin = File::Java->javabin();
    #my $cp = File::Java->cp( "$bindir/pennconverter.jar");

     my $command = "java -jar $bindir/pennconverter.jar"; 
        

     $SIG{PIPE} = 'IGNORE';    # don't die if parser gets killed
     my ( $reader, $writer, $pid ) = ProcessUtils::bipipe( $command );
 
     $self->{reader} = $reader;
     $self->{writer} = $writer;
     $self->{pid}    = $pid;
 
    bless $self;
    push @all_javas, $self;
}

sub parse {

#sendpenn style string to pennconverter.jar
my ($self) = shift @_;
my $s= shift @_;

#my $s = shift @_;
#my $s = "(S (NP (NNP John)) (VP (VBZ loves) (NP (NNP Mary))))";
my $size=shift @_;
my $writer = $self->{writer};
my $reader = $self->{reader};
        Report::fatal("Treex::Tools::Phrase2Dep::Pennconverter unexpected status") if ( !defined $reader || !defined $writer );

        print $writer "$s \n" ; 


my $counter=0;
my @results=();
my @indices=();
#print "---------\n";
while ($counter<$size){
$_=<$reader>;
#print $_;
my @tokens = split("\t",$_);
if($tokens[0]=~/\d/){
#print $tokens[0]."\t".$tokens[1]."\t".$tokens[2]."\t".$tokens[3]."\t".$tokens[4]."\t".$tokens[5]."\t".$tokens[6]."\n";
push(@results,$tokens[7]);
push(@indices,$tokens[6]);
$counter++;
}

}



return (\@results,\@indices);
#return <$reader>;<    
      

  return;
}




END {

    foreach my $java (@all_javas) {
        close( $java->{writer} );
        close( $java->{reader} );
        ProcessUtils::safewaitpid( $java->{pid} );
    }
}


1;
__END__


