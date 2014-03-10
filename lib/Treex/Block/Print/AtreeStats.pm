package Treex::Block::Print::AtreeStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' 				=> ( required => 1 );
has '+selector'		=> (required => 1);

has '_num_sentences' => (is => 'rw', isa => 'Int', default => 0);
has '_total_tokens' => (is => 'rw', isa => 'Int', default => 0);

sub process_atree {
    my ($self, $tree) = @_;
	my @nodes = $tree->get_descendants( { ordered => 1 } );
	$self->_set_num_sentences($self->_num_sentences + 1);
	$self->_set_total_tokens($self->_total_tokens + scalar(@nodes));    
}

sub process_end {
    my ($self) = @_;
	print "Number of Sentences:\t" . $self->_num_sentences . "\n";
	print "Number of Tokens:\t" .    $self->_total_tokens . "\n";
}

1;