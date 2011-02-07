package Treex::Tools::Parser::Charniak;

use Moose;
use MooseX::FollowPBP;


has sentence      => (isa => 'Str', is => 'rw', required => 1);


sub BUILD {
    my ( $self ) = @_;

    #to be changed
    my $bindir = "/home/green/tectomt/personal/green/tools/reranking-parser";
    my $command = "$bindir/parse.sh tmt_sentence.txt";

    die "Missing $bindir\n" if !-d $bindir;


#Write sentence to file (should be changed for a more efficient implementation later)
open FILE, ">$bindir/tmt_sentence.txt" or die $!; print FILE $self->{sentence}; close FILE;
   
#Change to bindir for the two order parse
chdir $bindir;
open DATA, "$command |"   or die "Couldn't execute program: $!"; 
   while ( defined( my $line = <DATA> )  ) {
     chomp($line);
     print "$line\n";
   }
   close DATA;

   
}


sub parse_sentence {

return;
 
}

1;

__END__


