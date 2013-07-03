package Treex::Block::Project::ATree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'modifier_dir' 		=> ( isa => 'Str', is => 'ro', default => 'mod_next' );
has '+selector' 		=> ( isa => 'Str', is => 'ro' );
has 'target_language'   => ( isa => 'Str', is => 'ro' );
has 'target_selector'   => ( isa => 'Str', is => 'ro', default => '' );
has 'alignment_type'    => ( isa => 'Str', is => 'rw', default => 'alignment' );
has 'chunk_head'        => ( isa => 'Str', is => 'ro', default => 'last' );
has 'head_within_chunk' => ( isa => 'Str', is => 'ro', default => 'mod_next' );

sub process_zone {
	my ( $self, $zone ) = @_;
	my $source_atree = $zone->get_atree();
	my $target_atree = $zone->get_bundle()->get_zone( $self->target_language, $self->target_selector )->get_atree();
	$self->project( $source_atree, $target_atree );
}

sub project {
	my ( $self, $source_root, $target_root ) = @_;
	my @target_nodes = $target_root->get_descendants( { ordered => 1 } );
	my @source_nodes = $source_root->get_descendants( { ordered => 1 } );

        # flatten the target tree first, to avoid possibly cycles when this projection is applied repeatedly
        foreach my $target_node (@target_nodes) {
            $target_node->set_parent($target_root);
        }

	# initialization of the projected tree
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
		my @aligned_nodes = ();
		@aligned_nodes = $src_node->get_aligned_nodes_of_type('^' . $self->alignment_type . '$');
		if (@aligned_nodes) {
			my $src_parent = $src_node->get_parent();
			my $chunk_head1 = $self->get_chunk_head( \@aligned_nodes );
			$self->attach_within_chunk( \@aligned_nodes, $chunk_head1 );
			if (defined($src_parent) && ($src_parent != $src_node) && ($src_parent != $source_root)) {
				my @aligned_nodes_for_src_parent =  $src_parent->get_aligned_nodes_of_type('^' . $self->alignment_type . '$' );
				if (@aligned_nodes_for_src_parent) {
					my $chunk_head2 = $self->get_chunk_head( \@aligned_nodes_for_src_parent );
					$self->attach_within_chunk( \@aligned_nodes_for_src_parent, $chunk_head2 );
	  				# cycle workaround (instead of skipping cycles):
	  				# if 'b' is a descendant of 'a' and if we are trying to hang 'a'
	  				# under 'b', then make the parent of 'b' pointing to the parent of 'a' and
	  				# rehang the 'a' under 'b'.
					if ($chunk_head1 != $chunk_head2) {
						if ($chunk_head2->is_descendant_of($chunk_head1)) {
							$chunk_head2->set_parent($chunk_head1->get_parent());
						}
						$chunk_head1->set_parent($chunk_head2);						
					}					
				}
			}
			elsif (defined($src_parent) && ( $src_parent != $src_node) && ($src_parent == $source_root )) {
				$chunk_head1->set_parent($target_root);
			}
		}
	}
}

sub get_chunk_head {
	my ( $self, $nodes_ref ) = @_;
	my @nodes = @{$nodes_ref};
	my @ns = sort { $a->ord <=> $b->ord } @nodes;
	if ( $self->chunk_head eq 'first' ) {
		return $ns[0];
	}
	elsif ( $self->chunk_head eq 'last' ) {
		return $ns[$#ns];
	}
}

sub attach_within_chunk {
	my ( $self, $nodes_ref, $root ) = @_;
	my @nodes = @{$nodes_ref};
	my @ns = sort { $a->ord <=> $b->ord } @nodes;
	if ($self->head_within_chunk eq 'mod_next') {
		if (scalar(@ns) >= 2) {
			foreach my $i (0 .. ($#ns - 1)) {
				if ($ns[$i] != $root) {
					if ($ns[$i+1]->is_descendant_of($ns[$i])) {
						$ns[$i+1]->set_parent($ns[$i]->get_parent());
					}
					$ns[$i]->set_parent($ns[$i + 1]);					
				}
			}
			if ($root == $ns[0]) {
				if ($root->is_descendant_of($ns[1])) {
					$root->set_parent($ns[1]->get_parent());
				}
				$ns[1]->set_parent($root);
			}
		}
	}	
	# other options
	# a) attach all nodes within the chunk to root node
	# b) probabilistic attachment within the chunk
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::Align::ATree - projects a dependency tree from one selector to another selector via 
alignment links

=head1 SYNOPSIS

 # projects a-tree in the current selector to the selector '' in zone 'ta'
 Project::ATree target_language='ta' target_selector='' alignment='union' 

 # using manual alignment
 Project::ATree target_language='ta' target_selector='' alignment='alignment'

=head1 DESCRIPTION

....

=head1 PARAMETERS

=over 4

=item C<modifier_dir>

this parameter takes care of the shape of the default projected tree. There are two options: 'mod_next' and 
'mod_prev'. 'mod_next' option leads to left branching tree and the 'mod_prev' option leads to right branching
tree.   

=item C<chunk_head>

determines the head of a given set of nodes. There are two options: 'first' - makes the first node to be returned as the head.
'last' - makes the last node to be returned as the head. The nodes are sorted according to 'ord' attribute before returning the head. 

=item C<head_within_chunk>

this parameters determines how the nodes within the chunk should be attached given the 'root' of the chunk. There are two options:
'mod_next' - modifies the next node according to the 'ord' attribute. 'mod_root' - all nodes within the chunk modify the 'root' 
node.

=back 

=head1 CAVEATS

Should find a way to extend the more general L<Treex::Block::Project::Tree>.

=head1 SEE ALSO

L<Treex::Block::Project::OneToOneEdges>, L<Treex::Block::Project::Tree>

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
