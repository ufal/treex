package Treex::Block::Print::AlignmentSummary;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has layer               => ( isa => 'Treex::Type::Layer', is => 'ro', default=> 'a' );
has source_language     => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has source_selector     => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has alignment_type      => ( isa => 'Str', is => 'ro', default => '.*', documentation => 'Use only alignments whose type is matching this regex. Default is ".*".' );
has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $source_zone = $zone->get_bundle()->get_zone( $self->source_language, $self->source_selector);
    my ($tree, $source_tree) = map {$_->get_tree($self->layer)} ($zone, $source_zone);	
    $self->print_alignment_info($source_tree, $tree);
}

sub print_alignment_info {
	my ($self, $src_tree, $tgt_tree) = @_;
	my $src_id;
	my $src_unaligned = 0;
	my $one_to_many = 0;
	my $many_to_one = 0;
	my $one_to_one = 0;
	my $src_len;
	my $tgt_id;
	my $tgt_unaligned = 0;
	my $tgt_len;
	my @src_nodes = $src_tree->get_descendants({ordered=>1});
	my @tgt_nodes = $tgt_tree->get_descendants({ordered=>1});
	if ($self->alignment_direction eq 'src2trg') {
		foreach my $i (0..$#src_nodes) {
			my @aligned_nodes = $src_nodes[$i]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
			if (@aligned_nodes) {
				if (scalar(@aligned_nodes) > 1) {
					$one_to_many++;	
				}
				elsif (scalar(@aligned_nodes) == 1) {
					my @referring_nodes = grep {$_->is_aligned_to($aligned_nodes[0], '^' . $self->alignment_type . '$')} $aligned_nodes[0]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
					if (scalar(@referring_nodes) == 1) {
						$one_to_one++;						
					}
					elsif (scalar(@referring_nodes) > 1) {
						$many_to_one++;
					}
				}
			}	
			else {
				$src_unaligned++;
			}
		}		
		foreach my $j (0..$#tgt_nodes) {
			my @referring_nodes = grep {$_->is_aligned_to($tgt_nodes[$j], '^' . $self->alignment_type . '$')} $tgt_nodes[$j]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
			if (!@referring_nodes) {
				$tgt_unaligned++;
			}
		}
	}
	my $out_string = sprintf("%20s %20s %4d %4d %4d %4d %4d %4d %4d", (substr $src_tree->id, 0, 20), (substr $tgt_tree->id, 0, 20), scalar(@src_nodes), scalar(@tgt_nodes), $src_unaligned, $tgt_unaligned, $one_to_many, $many_to_one, $one_to_one);
	print { $self->_file_handle } $out_string . "\n";
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::AlignmentSummary - prints useful information about the alignment between two trees

=head TODO

some description

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


