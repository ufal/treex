package Treex::Tools::PhraseParser::Charniak;

use Moose;

extends 'Treex::Tools::PhraseParser::Common';

sub prepare_parser_input {
    my ($self, $zones_rf) = @_;
    open my $INPUT, ">:utf8", $self->tmpdir."/input.txt" or log_fatal $!;
    foreach my $zone (@$zones_rf) {
#     
#         print $INPUT "<s> ".
#             (join " ", map{$_->form} $zone->get_atree->get_descendants({ordered=>1})).
#                 " </s>\n\n";
    my $string =  "<s> ";
    my @a_nodes= $zone->get_atree->get_descendants({ordered=>1});
    foreach my $a_node (@a_nodes){
     my $f = $a_node->form;
       $f=~ s/\s+//g;
    $string.=$f." ";
    }
    $string.="</s>\n\n";
    print $INPUT $string;
    }
    close $INPUT;
}



sub run_parser {
    my ($self) = @_;
    my $tmpdir = $self->tmpdir;
    my $bindir = "/net/work/people/green/Code/tectomt/personal/green/tools/reranking-parser";
    my $command = "cd $bindir; sh parse.sh $tmpdir/input.txt > $tmpdir/output.txt 2>$tmpdir/stderr.txt";
    system $command;
}


1;

__END__


