package Treex::Block::W2A::CopyAttribute;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has from_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has attr => ( isa => 'Str', is => 'ro', default => 'tag'); 

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );	

	# source tree from which the attr should be copied
	
	my $source_tree =  $root->get_zone()->get_bundle()->get_zone( $self->language, $self->from_selector )->get_atree();
	my @source_nodes = $source_tree->get_descendants({ordered => 1});
	
	foreach my $i (0..$#nodes) {
		my $attr_val = $source_nodes[$i]->get_attr($self->attr);
		$nodes[$i]->set_attr($self->attr, $attr_val);
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::CopyAttribute - Copies attribute from one zone to another

=head1 SYNOPSIS

 treex -Len Util::SetGlobal selector='orig' Read::Treex from=sample.treex.gz W2A::CopyAttribute from_selector='' attr='tag' 
 
 =head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
