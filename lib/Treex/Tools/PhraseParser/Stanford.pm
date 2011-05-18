package Treex::Tools::PhraseParser::Stanford;

use Moose;

extends 'Treex::Tools::PhraseParser::Common';

sub run_parser {
    my ($self)  = @_;
    my $tmpdir  = $self->tmpdir;
    my $bindir  = "/net/work/people/green/Code/tectomt/personal/green/tools/stanford-parser-2010-11-30";
    my $command = "cd $bindir; java -cp stanford-parser.jar edu.stanford.nlp.parser.lexparser.LexicalizedParser -tokenized -sentences newline wsjPCFG.ser.gz $tmpdir/input.txt > $tmpdir/output.txt 2>$tmpdir/stderr.txt";
    system $command;
    return;
}

1;

__END__


