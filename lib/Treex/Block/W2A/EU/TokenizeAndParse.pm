package Treex::Block::W2A::EU::TokenizeAndParse;
use Moose;
use Treex::Core::Common;
use Treex::Tool::IXAPipe::EU::TokenizeAndParse;
extends 'Treex::Core::Block';

has _parser => ( isa => 'Treex::Tool::IXAPipe::EU::TokenizeAndParse',
    is => 'ro', builder => '_build_parser');

my (@sentences, @zones);

sub _build_parser {
    my $self = shift;

    return Treex::Tool::IXAPipe::EU::TokenizeAndParse->new();
}

sub process_document {
    my ( $self, $doc ) = @_;

    @sentences = ();
    @zones = ();
    $self->Treex::Core::Block::process_document($doc);

    my $output = $self->_parser->parse_document(\@sentences);
    my @trees = split(/\n\n/, $output);

    if ($#trees != $#zones) {
        log_warn( "Different number of sentences in output." );
        log_fatal( "input: " . scalar @zones . " output: " . scalar @trees . "\n$output" );
    }

    for (my $i=0; $i<=$#zones; $i++) {
        my @nodes = split( "\n", $trees[$i] );
	my @anodes = ();
	my @parents = ();

	my $atree = $zones[$i]->create_atree();
	my $prev_node = undef;
        
        foreach my $j (0..$#nodes) {
            my ( $id, $form, $lemma, $postag, $ppos, $feats, $head, $deprel, @apreds ) = split( /\s+/, $nodes[$j] );

	    $prev_node = $atree->create_child({
		form           => $form,
		ord            => $i + 1,
		lemma          => $lemma,
		'conll/pos'    => $postag,
		'conll/cpos'   => $postag,
		'conll/feat'   => $feats,
		'conll/deprel'   => $deprel
	    });

	    push @anodes, $prev_node;
	    push @parents, $head;
        }

	foreach my $j (0..$#anodes) {
	    my $head = $parents[$j];
	    $anodes[$j]->set_parent( $anodes[ ($head-1) ] ) if ($head > 0);
	}
    }
    
    return 1;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    push @sentences, $zone->sentence;
    push @zones, $zone;

}

1;

__END__

