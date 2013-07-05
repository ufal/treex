package Treex::Block::Print::LemmaSequences;
use Treex::Core::Common;
use Moose;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );
	my @lemmas = ();
	foreach my $n (@nodes) {
		if (($n->lemma) && (length($n->lemma) > 0)) {
			push @lemmas, $n->lemma;			
		}
		else {
			push @lemmas, $n->form;
		}
	}
	my $sentence = join(" ", @lemmas);
	print { $self->_file_handle } $sentence, "\n";
}

1;

__END__