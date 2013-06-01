package Treex::Block::Align::PruneAlignmentForProjection;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'target_language' => (isa => 'Str', is => 'ro', required => 1);
has 'target_selector' => (isa => 'Str', is => 'ro', default => '');
has 'alignment_type' => (isa => 'Str', is => 'ro', required => 1);

sub process_zone {
	my ($self, $zone) = @_;
	my $source_atree = $zone->get_atree();
	my $target_atree = $zone->get_bundle()->get_zone($self->target_language, $self->target_selector)->get_atree();
	# prune one-to-many
	$self->prune_one_to_many($source_atree, $target_atree);	
	# prune many-to-one	
	$self->prune_one_to_many($source_atree, $target_atree);
	# prune one-to-one	
	$self->prune_one_to_many($source_atree, $target_atree);	
}

sub prune_one_to_many {
	my ($self, $source_tree, $target_tree) = @_;
	my @nodes = $source_tree->get_descendants( { ordered => 1 } );
	foreach my $node (@nodes) {
	    my ($alinks, $types) = $node->get_aligned_nodes();
	    if ($alinks) {
			my @aligned_nodes = @{$alinks};
		    my @a_types = @{$types};
		    my $tmpval = $self->alignment_type; 	
			my @atype_ind = grep {$a_types[$_] =~ /^($tmpval)$/}0..$#aligned_nodes;
			my @align_nodes_of_type = @aligned_nodes[@atype_ind];
	    	if (scalar(@align_nodes_of_type) > 1) {
	    		my @aligned_nodes_sorted = sort {$a->ord <=> $b->ord}@align_nodes_of_type;
	    		foreach my $i (0..($#aligned_nodes_sorted-1)){
	    			$node->delete_aligned_node($aligned_nodes_sorted[$i], $self->alignment_type);	
	    		}	    		
	    	}
	    }
	}
}

sub prune_many_to_one {
	my ($self, $source_tree, $target_tree) = @_;	
	return;
}

sub prune_one_to_one {
	my ($self, $source_tree, $target_tree) = @_;	
	return;	
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

=item C<prune_one_to_many>

prunes one source node aligned to many target nodes. The one-to-many alignment is reduced 
to one-to-one alignment. The alignment link is established to the last node (according 
to the order in which the node appears in the sentence) of the alignment links. 

=item C<prune_one_to_many>

=item C<prune_one_to_one>

=back

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.