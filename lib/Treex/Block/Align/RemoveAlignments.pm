package Treex::Block::Align::RemoveAlignments;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'layer' => ( is => 'ro', isa => 'Str', default => 'a' );
has '+selector' => ( is => 'ro', isa => 'Str', default => '' );
has 'alignment_type' => ( is => 'ro', isa => 'Str', default => 'alignment');

sub process_zone {
	my ( $self, $zone ) = @_;
	my $tree = $zone->get_tree($self->layer);
	my @nodes = $tree->get_descendants({ordered=>1});
	foreach my $n (@nodes) {
		my ($aligned_nodes_ref, $types_ref) = $n->get_directed_aligned_nodes();
		if (defined $aligned_nodes_ref) {
			my @aligned_nodes = @{$aligned_nodes_ref};	
			map{$n->delete_aligned_node($_, $self->alignment_type)}@aligned_nodes;
		}
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::RemoveAlignments - Removes alignment links of a given type from a tree

=head1 SYNOPSIS

 treex -Len Read::Treex from=sample.treex.gz Align::RemoveAlignments selector='syntax' alignment_type='berkeley' 
 
 =head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
  

