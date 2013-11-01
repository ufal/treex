package Treex::Block::A2A::FlattenAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants({ordered=>1});
	foreach my $n (@nodes) {
		$n->set_parent($root);
	}
}

1;

__END__