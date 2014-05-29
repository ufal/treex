package Treex::Block::Align::A::RemoveDuplicateLinks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# alignment links goes from 'selector' & 'language' to 'target_selector' & 'target_language' 
has 'target_language' => (isa => 'Str', is => 'ro', required => 1);
has 'target_selector' => (isa => 'Str', is => 'ro', required => 1);
has 'alignment_type' => ( is => 'ro', isa => 'Str', default => 'alignment');

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );	
	foreach my $node (@nodes) {
		my @aligned_nodes = $node->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->target_language, $self->target_selector);
		my %unique_links;
		if (@aligned_nodes) {
			map{$unique_links{$_->ord} = $_;}@aligned_nodes;
			map{$node->delete_aligned_node($_, $self->alignment_type)}@aligned_nodes;
			map{$node->add_aligned_node($unique_links{$_}, $self->alignment_type)}keys %unique_links;
		}
	}
			
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::A::RemoveDuplicateLinks - Removes duplicate alignment links

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
