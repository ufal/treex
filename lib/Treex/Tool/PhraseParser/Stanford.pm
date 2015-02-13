package Treex::Tool::PhraseParser::Stanford;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::PhraseParser::Common';
use Treex::Tool::ProcessUtils;

has use_tags => ( isa => 'Bool', is => 'rw', default => 0, );
has memory => ( isa => 'Str', is => 'rw', ); # default => '2G' 

sub run_parser {
    my ($self)  = @_;

    my $tmpdir  = $self->tmpdir;
	my $memory = $self->memory;

    my $bindir  = "$ENV{TMT_ROOT}/share/installed_tools/parser/stanford-parser-2010-11-30/";
    my $command = "cd $bindir; java -Xms$memory -cp stanford-parser.jar edu.stanford.nlp.parser.lexparser.LexicalizedParser";
	$command .= " -sentences newline -tokenized";
	$command .= " -tagSeparator /" if $self->use_tags;
	$command .= " wsjPCFG.ser.gz $tmpdir/input.txt > $tmpdir/output.txt 2>$tmpdir/stderr.txt";
	#print "$command\n";
    Treex::Tool::ProcessUtils::safesystem($command);
    return;
}


sub prepare_parser_input {
    my ( $self, $zones_rf ) = @_;
    my $tmpdir  = $self->tmpdir;
    open my $INPUT, ">:encoding(UTF-8)", $self->tmpdir . "/input.txt" or log_fatal $!;
    foreach my $zone (@$zones_rf) {

		if ($self->use_tags) {
			print $INPUT
				join ' ',
				map { $self->escape_form( $_->form ) . "/" . $_->tag }
				$zone->get_atree->get_descendants( { ordered => 1 } );
		}
		else {
			print $INPUT
				join ' ',
				map { $self->escape_form( $_->form ) }
				$zone->get_atree->get_descendants( { ordered => 1 } );
		}
        print $INPUT "\n";
    }
    close $INPUT;
    return;
}



1;

__END__



# modified by Lenka Smejkalova <smejkalova@ufal.mff.cuni.cz>