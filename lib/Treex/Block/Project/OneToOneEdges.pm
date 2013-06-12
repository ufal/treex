package Treex::Block::Project::OneToOneEdges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'modifier_dir' => (isa => 'Str', is => 'ro', default => 'mod_next');
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
	if ( $self->modifier_dir eq 'mod_prev' ) {
		if ( scalar(@target_nodes) >= 2 ) {
			foreach my $i ( 1 .. $#target_nodes ) {
				$target_nodes[$i]->set_parent( $target_nodes[ $i - 1 ] );
			}
		}
	}
	elsif ( $self->modifier_dir eq 'mod_next' ) {
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
			if (defined($src_parent) && ($src_parent != $src_node) && ($src_parent != $source_root)) {
				my @aligned_nodes_for_src_parent = $src_parent->get_aligned_nodes_of_type( '^' . $self->alignment_type . '$');
				if (scalar(@aligned_nodes_for_src_parent) == 1) {
					# cycle workaround (instead of skipping cycles):
					# if 'b' is a descendant of 'a' and if we are trying to hang 'a'
					# under 'b', then make the parent of 'b' pointing to the parent of 'a' and 
					# rehang the 'a' under 'b'.  
					if (!$aligned_nodes_for_src_parent[0]->is_descendant_of($aligned_nodes[0])) {
						$aligned_nodes[0]->set_parent($aligned_nodes_for_src_parent[0]);
					}
					else {
						$aligned_nodes_for_src_parent[0]->set_parent($aligned_nodes[0]->get_parent());
						$aligned_nodes[0]->set_parent($aligned_nodes_for_src_parent[0]);						
					}
				}				
			} 
			elsif (defined($src_parent) && ($src_parent != $src_node) && ($src_parent == $source_root)) {
				$aligned_nodes[0]->set_parent($target_root);
			}				
		}
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::OneToOneEdges - projects a dependency tree from one selector to another selector via 
alignment links. The alignment links are assumed to be one to one.

=head1 SYNOPSIS

 # projects a-tree in the current selector to the selector '' in zone 'ta'
 Project::OneToOneEdges target_language='ta' target_selector='' alignment='union' 

 # using manual alignment
 Project::OneToOneEdges target_language='ta' target_selector='' alignment='alignment'

=head1 DESCRIPTION

....

=head1 PARAMETERS

=over 4

=item C<modifier_dir>

this parameter takes care of the shape of the default projected tree. There are two options: 'mod_next' and 
'mod_prev'. 'mod_next' option leads to left branching tree and the 'mod_prev' option leads to right branching
tree.   

=back 

=head1 CAVEATS

Should find a way to extend the more general L<Treex::Block::Project::Tree>.

=head1 SEE ALSO

L<Treex::Block::Project::ATree>, L<Treex::Block::Project::Tree>

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.