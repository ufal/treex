package Treex::Block::Align::A::Retokenize;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

#has 'alignment_type' => (isa => 'Str', is => 'ro', required => 1);

sub process_atree {
	my ( $self, $root ) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );

	foreach my $node (@nodes) {
		if ( $node->form =~ /^([^\s]+)(\p{IsP}+)$/ ) {

			# step 1: add a new node for the punctuation symbol
			print "RETOKENIZING " . $node->form . " into =>\t" . $1 . "\tand\t" . $2 ."\n";
			$node->set_form($1);
			my $new_node = $root->create_child( form => $2 );
			$new_node->shift_after_node($node);
			$node->set_no_space_after(1);

			# step 2: split the list of alignment links

			my ( $ali_nodes_rf, $ali_types_rf ) = $node->get_directed_aligned_nodes;

			if ($ali_nodes_rf) {
				foreach my $index ( 0 .. $#$ali_nodes_rf ) {
					my $aligned_node = $ali_nodes_rf->[$index];

					if ( $aligned_node->form =~ /^\p{IsP}+$/ ) {
						my $type = $ali_types_rf->[$index];
						$new_node->add_aligned_node( $aligned_node, $type );
						$node->delete_aligned_node( $aligned_node, $type );
					}
				}
			}
		}
	}

	@nodes = $root->get_descendants({ordered=>1});
	
	foreach my $node (@nodes) {
		if ( $node->form =~ /^(\p{IsP}+)([^\s]+)$/ ) {
			print "RETOKENIZING " . $node->form . " into =>\t" . $1 . "\tand\t" . $2 ."\n";
			$node->set_form($2);
			my $new_node = $root->create_child( form => $1 );
			$new_node->shift_before_node($node);
			$new_node->set_no_space_after(1);

			my ( $ali_nodes_rf, $ali_types_rf ) = $node->get_directed_aligned_nodes;

			if ($ali_nodes_rf) {
				foreach my $index ( 0 .. $#$ali_nodes_rf ) {
					my $aligned_node = $ali_nodes_rf->[$index];
					if ( $aligned_node->form =~ /^\p{IsP}+$/ ) {
						my $type = $ali_types_rf->[$index];
						$new_node->add_aligned_node( $aligned_node, $type );
						$node->delete_aligned_node( $aligned_node, $type );
					}
				}
			}
		}		
	}		
}

1;

__END__
