package Treex::Block::A2A::CopyAlignments;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'layer' => ( is => 'rw', isa => 'Str', default => 'a' );
has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );
has 'copy_links_to_selector' => ( is => 'rw', isa => 'Str', default => '' );
has 'alignment_type' => ( isa => 'Str', is => 'ro', default => '.*', documentation => 'Use only alignments whose type is matching this regex. Default is ".*".' );

sub process_zone {
    my ( $self, $zone ) = @_;
    my $target_zone = $zone->get_bundle()->get_zone( $self->to_language, $self->to_selector);
    my $new_target_zone = $zone->get_bundle()->get_zone( $self->to_language, $self->copy_links_to_selector);
    my ($src_tree, $tgt_tree, $new_tgt_tree) = map {$_->get_tree($self->layer)} ($zone, $target_zone, $new_target_zone);
	my @src_nodes = $src_tree->get_descendants({ordered=>1});
	my @tgt_nodes = $tgt_tree->get_descendants({ordered=>1});
	my @new_tgt_nodes = $new_tgt_tree->get_descendants({ordered=>1});
	foreach my $i (0..$#src_nodes) {
		my @aligned_nodes = $src_nodes[$i]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->to_language, $self->to_selector);
		if (@aligned_nodes) {
			foreach my $an (@aligned_nodes) {
				my $to_ord = $an->ord;
				$src_nodes[$i]->add_aligned_node($new_tgt_nodes[$to_ord-1], $self->alignment_type );			
			}
		}
	}	    	
} 

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CopyAlignments - copies alignments from one selector to another selector

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


