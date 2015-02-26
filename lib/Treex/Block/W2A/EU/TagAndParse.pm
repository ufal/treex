package Treex::Block::W2A::EU::TagAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Tool::IXAPipe::EU::TokenizeAndParse;
extends 'Treex::Core::Block';

has _parser => ( isa => 'Treex::Tool::IXAPipe::EU::TokenizeAndParse',
    is => 'ro', builder => '_build_parser');

my (@sentences, @atrees);

sub _build_parser {
    my $self = shift;

    return Treex::Tool::IXAPipe::EU::TokenizeAndParse->new();
}

sub process_document {
    my ( $self, $doc ) = @_;

    @sentences = ();
    @atrees = ();
    $self->Treex::Core::Block::process_document($doc);

    $self->_parser->set_onWhitespaces(1);
    my $output = $self->_parser->parse_document(\@sentences);
    my @trees = split(/\n\n/, $output);

    my $analysis_error=0;
    if ($#trees != $#atrees) {
	### give a second chance
	$output = $self->_parser->parse_document(\@sentences);
	@trees = split(/\n\n/, $output);
	if ($#trees != $#atrees) {
	    log_warn( "Different number of sentences in output (". $doc->full_filename .")." );
	    #log_fatal( "input: " . scalar @atrees . " output: " . scalar @trees . "\n$output\n" . join("\n", @sentences) );

	    ## don't raise a fatal error. Add dummy analysis
	    log_warn( "input: " . scalar @atrees . " output: " . scalar @trees . "\n$output\n" . join("\n", @sentences) );
	    $analysis_error = 1;
	}
    }

    for (my $i=0; $i<=$#atrees; $i++) {
        my @nodes;
	@nodes = split( "\n", $trees[$i] ) if (!$analysis_error);
	my @anodes = $atrees[$i]->get_descendants({ordered=>1});

	if ($analysis_error || $#nodes != $#anodes) {
	    log_warn( "Different number of tokens in output." );
	    log_warn( "input nodes: " . scalar @anodes . " output nodes: " . scalar @nodes );
	}

        foreach my $j (0..$#anodes) {
	    if ($#nodes != $#anodes) {
		$anodes[$j]->set_lemma($anodes[$j]->form);
		$anodes[$j]->set_tag("x");
		$anodes[$j]->set_conll_pos("");
		$anodes[$j]->set_conll_feat("");
		$anodes[$j]->set_conll_deprel("");
	    }
	    else {
		my ( $id, $form, $lemma, $cpos, $pos, $feat, $head, $deprel, @apreds ) = split( /\s+/, $nodes[$j] );

		$anodes[$j]->set_form($form);
		$anodes[$j]->set_lemma($lemma);
		$anodes[$j]->set_tag($pos);
		$anodes[$j]->set_conll_cpos($cpos);
		$anodes[$j]->set_conll_pos($pos);
		$anodes[$j]->set_conll_feat($feat);
		$anodes[$j]->set_conll_deprel($deprel);

		$anodes[$j]->set_parent( $anodes[ ($head -1) ] ) if ($head > 0);
	    }
        }
    }
    
    return 1;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my $text;

    my @anodes = $atree->get_descendants({ordered=>1});
    my $tooLong = (@anodes >= 100 || @anodes == 0); ## Parser discards sentences longer than 100 tokens. Don't send them to avoid different number of sentences in output.

    foreach my $anode (@anodes){
	if ($tooLong) {
            $anode->set_lemma($anode->form);
            $anode->set_tag("x");
	    $anode->set_conll_pos("");
	    $anode->set_conll_feat("");
	    $anode->set_conll_deprel("");
	}
	else {
	    $text .= " " if defined $text;
	    $text .= $anode->form;
	}
    }

    #$text =~ s/[^a-záéíóúñA-ZÁÉÍÓÚÑ0-9\.,:;\-'\"\/!\?º%\^~#&\*\+=\|\{\}<>¿¡\(\)\[\]_\\\s]/#/g;

    if (!$tooLong) {
	push @sentences, $text;
	push @atrees, $atree;
    }
}

1;

__END__

