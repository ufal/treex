package Treex::Block::Misc::AddZonesFromFile;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'from_file'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'from_zone'     => ( is => 'ro', isa => 'Str', required => 1 );
has 'from_selector' => ( is => 'ro', isa => 'Str', default => '' );
has 'to_selector' =>
  ( is => 'ro', isa => 'Str', predicate => 'has_destination' );

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
	foreach my $i (0..$#bundles) {
		my $zone_to_copy = $from_bundles[$i]->get_zone($self->from_zone, $self->from_selector);
		my $new_zone = $bundles[$i]->create_zone($self->from_zone, $destination);
		if ( $zone_to_copy->has_atree() ) {
			my $new_zone_atree = $new_zone->create_atree();
			my $atree_to_copy  = $zone_to_copy->get_atree();
			$atree_to_copy->copy_atree($new_zone_atree);
		}
	}
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::AddZonesFromFile - copies zone from external treex documents to another treex document.

=head1 SYNOPSIS

  # Copies zone from a particular selector to the current document.
  Misc::AddZonesFromFile from_file=abc.treex.gz from_zone='en' from_selector='mst'
  

=head1 DESCRIPTION

This block facilitates copying of a zone from one treex document to another. This block is useful in 
situations where various zones are produced (from similar NLP tasks) externally of treex 
framework and we want to combine those zones in a single treex document.  

=head1 PARAMETERS

=over 4

=item C<from_file>

The name of the treex file. This parameter is required.

=item C<from_zone>

The name of the zone, in other words the 2-letter language code. This parameter is required.

=item C<from_selector>

The name of the selector within the zone to be copied. The default value is ''.

=item C<to_selector>

To which selector the copying zone must be assigned in the destination treex document. 
If this parameter is not specified, then the C<from_selector> will be used instead. 

=back

=head1 TODO

At present, the block copies only a-trees of the zone to another treex document. Copying of other 
trees such as t-trees could be useful.

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
 
