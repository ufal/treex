package Treex::Tool::PhraseParser::Charniak;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::PhraseParser::Common';
use Treex::Tool::ProcessUtils;

sub prepare_parser_input {
    my ( $self, $zones_rf ) = @_;
    open my $INPUT, ">:encoding(UTF-8)", $self->tmpdir . "/input.txt" or log_fatal $!;
    foreach my $zone (@$zones_rf) {
        print $INPUT "<s> ",
            join ' ',
            map { $self->escape_form( $_->form ) }
            $zone->get_atree->get_descendants( { ordered => 1 } );
        print $INPUT " </s>\n\n";
    }
    close $INPUT;
    return;
}

sub run_parser {
    my ($self)  = @_;
    my $tmpdir  = $self->tmpdir;
    my $bindir  = "$ENV{TMT_ROOT}/share/installed_tools/reranking-parser";
    my $command = "cd $bindir; sh parse.sh $tmpdir/input.txt > $tmpdir/output.txt 2>$tmpdir/stderr.txt";
    Treex::Tool::ProcessUtils::safesystem($command);
}

1;

__END__


