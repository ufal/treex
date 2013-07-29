package Treex::Block::Align::PruneAlignmentForProjection;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'target_language' => (isa => 'Str', is => 'ro', required => 1);
has 'target_selector' => (isa => 'Str', is => 'ro', default => '');
has 'alignment_type' => (isa => 'Str', is => 'ro', required => 1);

has 'prune_one_to_many' => (isa => 'Bool', is => 'ro', default => 0);
has 'prune_many_to_one' => (isa => 'Bool', is => 'ro', default => 0);
has 'delete_erroneous_links' => (isa => 'Bool', is => 'ro', default=> 1);


sub process_zone {
	my ($self, $zone) = @_;
	my $source_atree = $zone->get_atree();
	my $target_atree = $zone->get_bundle()->get_zone($self->target_language, $self->target_selector)->get_atree();

	# prune one-to-many
	if ($self->prune_one_to_many) {
		$self->prune_one_to_many($source_atree, $target_atree);	
	}
		
	# prune many-to-one
	if ($self->prune_many_to_one) {
		$self->prune_many_to_one($source_atree, $target_atree);	
	}	
	
	# delete erroneous alignments
	if ($self->delete_erroneous_links) {
		$self->delete_erroneous_alignments($source_atree, $target_atree);	
	}

}

sub prune_one_to_many {
	my ($self, $source_tree, $target_tree) = @_;
	my @nodes = $source_tree->get_descendants( { ordered => 1 } );
	foreach my $node (@nodes) {
	    my @aligned_nodes = $node->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->target_language, $self->target_selector);
	    	if (scalar(@aligned_nodes) > 1) {
	    		my @aligned_nodes_sorted = sort {$a->ord <=> $b->ord}@aligned_nodes;
	    		foreach my $i (0..($#aligned_nodes_sorted-1)){
	    			$node->delete_aligned_node($aligned_nodes_sorted[$i], $self->alignment_type);	
	    		}	    		
	    	}
	}
	return;
}

sub prune_many_to_one {
	my ($self, $source_tree, $target_tree) = @_;
	my @nodes = $target_tree->get_descendants( { ordered => 1 } );
	foreach my $node (@nodes) {
		my @referring_nodes = grep{ $_->is_aligned_to($node, '^' . $self->alignment_type . '$')}$node->get_referencing_nodes('alignment');
		if (scalar(@referring_nodes) > 1) {
			my @referring_nodes_sorted = sort {$a->ord <=> $b->ord}@referring_nodes;	
			foreach my $i (0..($#referring_nodes_sorted-1)) {
				$referring_nodes_sorted[$i]->delete_aligned_node($node, $self->alignment_type);
			}		
		}
	}
	return;
}

sub delete_erroneous_alignments {
	my ($self, $source_tree, $target_tree) = @_;
	my @nodes = $source_tree->get_descendants( { ordered => 1 } );
	
	# (i) remove alignment if a punctuation is aligned to a form on the other side
	foreach my $node (@nodes) {
		my @aligned_nodes = $node->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->target_language, $self->target_selector);
		if (@aligned_nodes) {
			foreach my $an (@aligned_nodes) {
				if ((($node->form =~ /^\p{IsP}$/) && ($an->form !~ /^\p{IsP}$/)) || (($node->form !~ /^\p{IsP}$/) && ($an->form =~ /^\p{IsP}$/))) {
					$node->delete_aligned_node($an, $self->alignment_type);
				}
			}
		}
	}		
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::PruneAlignmentForProjection - prunes alignment of a given alignment type

=head1 SYNOPSIS

Align::PruneAlignment target_language='ta' target_selector='' alignment='union'
Align::PruneAlignment target_language='ta' target_selector='' alignment='grow-diag-final-and'

=head1 DESCRIPTION

Performs a sort of post-processing on the alignment links between two a-trees. 

=head1 METHODS

=over 10

=item C<delete_erroneous_links>

enabling this option makes sure that some language independent erroneous alignment links are deleted. 
For example, the alignment is most likely to be erroneous if a "punctuation" on the source side is aligned
to a "form" on the target side or vice versa. 

=item C<prune_one_to_many>

prunes one source node aligned to many target nodes. The one-to-many alignment is reduced 
to one-to-one alignment. The alignment link is established to the last node (according 
to the order in which the node appears in the sentence) of the alignment links. 

=item C<prune_one_to_many>

prunes multiple source nodes aligned to a single target node. This method reduces many-to-one 
alignment into one-to-one alignment by keeping only the last aligned node and deleting alignments
from remaining source nodes to the target node.

=back

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.