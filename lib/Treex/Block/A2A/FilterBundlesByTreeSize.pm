package Treex::Block::A2A::FilterBundlesByTreeSize;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Block::Print::AlignmentStatistics;

has layer => ( isa => 'Treex::Type::Layer', is => 'ro', default => 'a' );
has max_length => (isa => 'Int', is => 'ro', default => 80);
	
sub process_bundle {
	
	my ( $self, $bundle ) = @_;
	
	my @all_zones = $bundle->get_all_zones();
	
	foreach my $z (@all_zones) {
		my $tree = $z->get_tree( $self->layer );
		my @nodes = $tree->get_descendants( { ordered => 1 } );
		if (scalar(@nodes) > $self->max_length) {
			$bundle->remove();
			last;
		}			
	}
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::FilterBundlesByTreeSize - filters bundles by tree size

=head1 SYNOPSIS

 # max number of nodes = 100
 treex Read::Treex from=test.treex.gz A2A::FilterTreesByLength max_length=100 

=head1 DESCRIPTION

This block applies to whole bundle. The criteria will be checked against trees in the zones. If any zone contains a tree that has more number of nodes than the 'max_length', the bundle will be removed.
    
=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.