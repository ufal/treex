package Treex::Block::Project::ATreeRecursive;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'modifier_dir' 		=> ( isa => 'Str', is => 'ro', default => 'mod_next' );
has '+selector' 		=> ( isa => 'Str', is => 'ro' );
has 'target_language'   => ( isa => 'Str', is => 'ro' );
has 'target_selector'   => ( isa => 'Str', is => 'ro', default => '' );
has 'alignment_type'    => ( isa => 'Str', is => 'rw', default => 'alignment' );
has 'chunk_head'        => ( isa => 'Str', is => 'ro', default => 'last' );
has 'head_within_chunk' => ( isa => 'Str', is => 'ro', default => 'mod_next' );

my %unattached_target_nodes = ();

sub process_zone {
	my ( $self, $zone ) = @_;
	my $source_atree = $zone->get_atree();
	my $target_atree = $zone->get_bundle()->get_zone( $self->target_language, $self->target_selector )->get_atree();	
	my @target_nodes = $target_atree->get_descendants( { ordered => 1 } );
	my @source_nodes = $source_atree->get_descendants( { ordered => 1 } );
	
	# initialization of the projected tree
	if ( $self->modifier_dir eq 'mod_prev' ) {
		if ( scalar(@target_nodes) >= 2 ) {
			foreach my $i ( 1 .. $#target_nodes ) {
				$target_nodes[$i]->set_parent( $target_nodes[ $i - 1 ] );
			}
		}
	}
	elsif ( $self->modifier_dir eq 'mod_next' ) {
		if ( scalar(@target_nodes) >= 2 ) {
			foreach my $i ( 0 .. ( $#target_nodes - 1 ) ) {
				$target_nodes[$i]->set_parent( $target_nodes[ $i + 1 ] );
			}
		}
	}	
	$self->project( $source_atree, $target_atree );	
}


sub project {
	my ($self, $source_parent, $target_parent) = @_;
	my @source_children = $source_parent->get_children();
	foreach my $sc (@source_children) {
		my @aligned_nodes = $sc->get_aligned_nodes_of_type('^' . $self->alignment_type . '$');
		if (@aligned_nodes) {
			my $chunk_head = $self->get_chunk_head( \@aligned_nodes );
			if (!$target_parent->is_descendant_of($chunk_head) && ($chunk_head != $target_parent)) {
				$chunk_head->set_parent($target_parent);
				$self->project($sc, $chunk_head);
			}
			else {
				log_warn "There seems to be cycle when attaching. Falling back !!!\n";
				$self->project($sc, $target_parent);
			}			
		}
		else {
			$self->project($sc, $target_parent);
		}
	}
}

sub get_chunk_head {
	my ( $self, $nodes_ref ) = @_;
	my @nodes = @{$nodes_ref};
	my @ns = sort { $a->ord <=> $b->ord } @nodes;
	if ( $self->chunk_head eq 'first' ) {
		return $ns[0];
	}
	elsif ( $self->chunk_head eq 'last' ) {
		return $ns[$#ns];
	}
}

1;

__END__
