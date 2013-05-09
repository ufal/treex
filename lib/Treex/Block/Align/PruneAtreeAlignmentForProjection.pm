package Treex::Block::Align::PruneAtreeAlignmentForProjection;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( isa => 'Str', is => 'ro', required => 1 );
has 'keep_contiguous' => (isa => 'Bool', is=> 'rw', default=> 1);
has 'source_selector' => (isa => 'Str', is => 'rw', default=> '');

sub process_atree {
    my ( $self, $root ) = @_;
    my @nodes = $root->get_descendants( { ordered => 1 } );
	foreach my $i (0..$#nodes) {
		my $node = $nodes[$i];
		$self->delete_discontinuous_alignments($node);
	}
}

sub delete_discontinuous_alignments {
	my ($self, $node) = @_;
    my ($alinks, $types) = $node->get_aligned_nodes();
    if ($alinks) {
    	my $num_alinks = scalar(@{$alinks});
    	if ($num_alinks > 1) {
	    	my @keep = (0) x ($num_alinks);
	    	my $reg = 0;
			foreach my $i (0..($num_alinks-2)) {
				my $aord = $alinks->[$i]->ord;
				my $bord = $alinks->[$i+1]->ord;
				if (($aord == ($bord-1)) || ($aord == $bord)) {
					if (($keep[$i] == 0) && ($keep[$i+1] == 0)) {
						$reg++;
						$keep[$i] = $reg;
						$keep[$i+1] = $reg; 
					}
					elsif (($keep[$i] != 0) && ($keep[$i+1] == 0)) {
						$keep[$i+1] = $keep[$i];						
					}
				}
			}
			# delete non-contiguous nodes
			# only one cluster of nodes (1st cluster) will survive
			foreach my $i (0..$#keep) {
				if ($keep[$i] != 1) {
					my $to_del_node = $alinks->[$i];
					my $to_del_type = $types->[$i];
					$node->delete_aligned_node($to_del_node, $to_del_type);
				}
			}			
    	}
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::PruneAtreeAlignmentForProjection - Language Independent Rules for Filtering the Alignments 

