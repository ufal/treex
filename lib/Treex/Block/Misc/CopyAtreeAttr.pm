package Treex::Block::Misc::CopyAtreeAttr;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'to_selector' => ( is => 'ro', isa => 'Str', required => 1 );
has 'attr'        => ( is => 'ro', isa => 'Str', required => 1 );

sub process_atree {
	my ( $self, $src_root ) = @_;
	my $bundle    = $src_root->get_bundle;
	my $to_zone   = $bundle->get_zone( $self->language, $self->to_selector );
	my $tgt_root  = $to_zone->get_atree();
	my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
	my @tgt_nodes =
	  $tgt_root->get_descendants( { ordered => 1 } );
	if ($#src_nodes != $#tgt_nodes) {
		log_fatal 'number of nodes in trees differ: ' . scalar(@src_nodes) . " not equal to " . scalar(@tgt_nodes);
	} 
	my $attr_key = $self->attr;
	foreach my $i (0..$#src_nodes) {
		my $attr_val = $src_nodes[$i]->get_attr($attr_key);
		$tgt_nodes[$i]->set_attr($attr_key, $attr_val);
	}	
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CopyAtreeAttr - copies a given attr from one a-tree to another a-tree
