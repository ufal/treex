package Treex::Block::Misc::FixMissingZones;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language' => (is => 'ro', isa => 'Str');
has 'selector' => (is => 'ro', isa => 'Str');

sub process_bundle {
	my ($self, $bundle, $bundleNo) = @_;
	my $zone = $bundle->get_zone($self->language, $self->selector);
	if (!defined $zone) {
		print "Fixing bundle: $bundleNo\n";
		my $new_zone = $bundle->create_zone($self->language, $self->selector);
		my $atree = $new_zone->create_atree();
		$atree->create_child(form=>'???',ord=>1);
	}
	elsif (defined $zone && !$zone->has_atree()) {
		print "Fixing bundle: $bundleNo\n";		
		my $atree = $zone->create_atree();
		$atree->create_child(form=>'???',ord=>1);		
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::FixMissingZones - creates a dummy a-tree if it does not exist in a zone 

=head1 DESCRIPTION

Sometimes, applying chain of blocks might impose a-trees to be present in the zones. If they are unavailable for some reasons,
then the entire pipeline collapses. To avoid that, a dummy a-tree is created to stop breaking the 
pipeline.
