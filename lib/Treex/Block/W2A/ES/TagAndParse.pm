package Treex::Block::W2A::ES::TagAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Tool::IXAPipe::ES::TagAndParse;
extends 'Treex::Core::Block';

has tagger_memory => ( is => 'ro', isa => 'Str', default => '512m' );
has parser_memory => ( is => 'ro', isa => 'Str', default => '2000m' );

has _parser => ( is => 'rw', isa => 'Treex::Tool::IXAPipe::ES::TagAndParse');

my (@sentences, @atrees);

sub BUILD {
  my ($self) = @_;
  my $parser = Treex::Tool::IXAPipe::ES::TagAndParse->new({
      tagger_memory => $self->tagger_memory,
      parser_memory => $self->parser_memory,
  });
  $self->_set_parser($parser);
  return;
}

sub process_document {
    my ( $self, $doc ) = @_;

    @sentences = ();
    @atrees = ();
    $self->Treex::Core::Block::process_document($doc);

    my $output = $self->_parser->parse_document(\@sentences);
    my @trees = split(/\n\n/, $output);

    if ($#trees != $#atrees) {
        log_warn( "Different number of sentences in output." );
        log_fatal( "input: " . scalar @atrees . " output: " . scalar @trees . "\n$output" );
    }

    for (my $i=0; $i<=$#atrees; $i++) {
        my @nodes = split( "\n", $trees[$i] );
        my @anodes = $atrees[$i]->get_descendants({ordered=>1});
        
        if ($#nodes != $#anodes) {
            log_warn( "Different number of tokens in output." );
            log_warn( "input nodes: " . scalar @anodes . " output nodes: " . scalar @nodes );
            splice @trees, $1, 0, "-\n" if ($#trees < $#atrees);
            next;
        }

        foreach my $j (0..$#anodes) {
            my ( $id, $form, $lemma, $plemma, $postag, $ppos, $pfeats, $feats, $head, $phead, $deprel, $pdeprel, $fillpred, $pred, @apreds ) = split( /\s+/, $nodes[$j] );
            $anodes[$j]->set_form($form);
            $anodes[$j]->set_lemma($lemma);
            $anodes[$j]->set_tag($postag);
            $anodes[$j]->set_conll_cpos($postag);
            $anodes[$j]->set_conll_pos($postag);
            $anodes[$j]->set_conll_feat($feats);
            $anodes[$j]->set_conll_deprel($deprel);

            $anodes[$j]->set_parent( $anodes[ ($head -1) ] ) if ($head > 0);
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
	    $anode->set_conll_deprel("NR");
	}
	else {
	    $text .= " " if defined $text;
	    $text .= $anode->form;
	}
    }

    if (!$tooLong) {
	push @sentences, $text;
	push @atrees, $atree;
    }
}

1;

__END__

