package Treex::Block::Misc::ImportATreesFromFile;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'from_file'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'from_zone'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'from_selector' => ( is => 'ro', isa => 'Str', default => q{} );
has 'to_selector' =>
  ( is => 'ro', isa => 'Str', predicate => 'has_destination' );

# comma separated a-tree ids
has 'ids' => (is => 'ro', isa=> 'Str', required=> 1);  

my %id_hash = ();

sub process_document {
	my ( $self, $doc ) = @_;
	my @bundles = $doc->get_bundles();
	my $from_doc =
	  Treex::Core::Document->new( { filename => $self->from_file } )
	  ;
	my @from_bundles = $from_doc->get_bundles();
	
	if ( scalar(@bundles) != scalar(@from_bundles) ) {
		log_fatal( "The number of bundles from "
			  . $doc->full_filename
			  . " and the number of bundles from "
			  . $from_doc->full_filename
			  . " should match" );
	}	
	
	my $destination = $self->from_selector;
	$destination = $self->to_selector if $self->has_destination;
	
	# create ids hash
	my @id_numbers = split(/\s*,\s*/, $self->ids);
	if ($self->from_selector eq q{}) {
		map{ $id_hash{'a_tree-'. $self->from_zone . '-' . 's' . $_ .'-root'}++;}@id_numbers;
	}
	else {
		map{ $id_hash{'a_tree-'. $self->from_zone . '_' . $self->from_selector . '-' . 's' . $_ .'-root'}++;}@id_numbers;
	}
	
	foreach my $i (0..$#from_bundles) {
		# zone of the a-tree to be copied
		my $src_zone = $from_bundles[$i]->get_zone($self->from_zone, $self->from_selector);
		# zone of the a-tree to be replaced
		my $tgt_zone = $bundles[$i]->get_zone($self->from_zone, $destination);
		
		if ( $src_zone->has_atree() ) {
			my $src_atree = $src_zone->get_atree();
			if (exists $id_hash{$src_atree->id}) {
				print "Copying a-tree: " . $src_atree->id . " from " . $self->from_file . "\n"; 
				$tgt_zone->remove_tree('a');
				my $new_atree = $tgt_zone->create_atree();
				$src_atree->copy_atree($new_atree);				
			} 
		}
	}
}  


1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::Misc::ImportATreesFromFile - copies a-trees from another file 

=head1 SYNOPSIS

  # Copy certain a-trees from A.treex.gz into B.treex.gz  
  # The following command copies the a-trees with the following ids: a_tree-ta-s10-root, a_tree-ta-s13-root, a_tree-ta-s15-root, a_tree-ta-s30-root
  treex -Lta Read::Treex from=B.treex.gz Misc::ImportATreesFromFile from_file=A.treex.gz from_zone=ta from_selector='' ids=10,13,15,30 Write::Treex to=copied.treex.gz
  

=head1 DESCRIPTION

Imagine that there two treex files A.treex.gz and B.treex.gz, the former is an older version and the later is a newer version. 
You want to retain some trees in A.treex.gz (older version) in the B.treex.gz. So, given the comma separated a-tree ids (only integer part of the ida ),
A.tree.gz, the block copies those a-trees into the B.treex.gz (replacing those already present).  


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. 

