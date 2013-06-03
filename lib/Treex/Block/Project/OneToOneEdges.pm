package Treex::Block::Project::OneToOneEdges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'mod_dir' => (isa => 'Str', is => 'ro', default => 'mod_next');
has '+selector' => (isa => 'Str', is => 'ro');
has 'target_language' => (isa => 'Str', is => 'ro');
has 'target_selector' => (isa => 'Str', is => 'ro', default => '');
has 'alignment_type' => (isa => 'Str', is => 'rw', default => 'alignment');
 
sub process_zone {
	my ($self, $zone) = @_;
	my $source_atree = $zone->get_atree();
	my $target_atree = $zone->get_bundle()->get_zone($self->target_language, $self->target_selector)->get_atree();
	$self->project($source_atree, $target_atree);
}

sub project {
	my ($self, $source_root, $target_root) = @_;
	my @target_nodes = $target_root->get_descendants( { ordered => 1 } );
	my @source_nodes = $source_root->get_descendants( { ordered => 1 } );	

	# default target tree initialization 
	if ( $self->mod_dir eq 'mod_prev' ) {
		if ( scalar(@target_nodes) >= 2 ) {
			foreach my $i ( 1 .. $#target_nodes ) {
				$target_nodes[$i]->set_parent( $target_nodes[ $i - 1 ] );
			}
		}
	}
	elsif ( $self->mod_dir eq 'mod_next' ) {
		if ( scalar(@target_nodes) >= 2 ) {
			foreach my $i ( 0 .. ( $#target_nodes - 1 ) ) {
				$target_nodes[$i]->set_parent( $target_nodes[ $i + 1 ] );
			}
		}
	}
	foreach my $src_node (@source_nodes) {
		my @aligned_nodes = $src_node->get_aligned_nodes_of_type( '^' . $self->alignment_type . '$');
		if (scalar(@aligned_nodes) == 1) {
			my $src_parent = $src_node->get_parent();
			if (defined($src_parent) && ($src_parent != $src_node)) {
				my @aligned_nodes_for_src_parent = $src_parent->get_aligned_nodes_of_type( '^' . $self->alignment_type . '$');
				if (scalar(@aligned_nodes_for_src_parent) == 1) {
					if (!$aligned_nodes_for_src_parent[0]->is_descendant_of($aligned_nodes[0])) {
						$aligned_nodes[0]->set_parent($aligned_nodes_for_src_parent[0]);
					}
				}				
			} 
		}
	}
}

1;

__END__