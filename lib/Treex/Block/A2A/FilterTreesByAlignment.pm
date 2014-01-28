package Treex::Block::A2A::FilterTreesByAlignment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Block::Print::AlignmentStatistics;

has layer => ( isa => 'Treex::Type::Layer', is => 'ro', default => 'a' );
has source_language =>
  ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has source_selector =>
  ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );
has alignment_type => (
	isa     => 'Str',
	is      => 'ro',
	default => '.*',
	documentation =>
	  'Use only alignments whose type is matching this regex. Default is ".*".'
);
has alignment_direction => (
	is      => 'ro',
	isa     => enum( [qw(src2trg trg2src)] ),
	default => 'trg2src',
	documentation =>
'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);

# other options: '1-1', '1-1-perfect'
has filtering_options => (
	is      => 'ro',
	isa     => 'Str',
	default => 'none'
);

has max_src_unalign_rate => ( is => 'ro', isa => 'Num', default => 0.5 );
has max_tgt_unalign_rate => ( is => 'ro', isa => 'Num', default => 0.5 );

sub process_bundle {

	my ( $self, $bundle ) = @_;

	my @all_zones = $bundle->get_all_zones();

	my $src_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
	my $tgt_zone = $bundle->get_zone( $self->language, $self->selector );
	my $src_tree = $src_zone->get_tree( $self->layer );
	my $tgt_tree = $tgt_zone->get_tree( $self->layer );

	my %status = $self->get_alignment_status( $src_tree, $tgt_tree );
	
	my $src_una_rate = $status{'src-unalignment-rate'};
	my $tgt_una_rate = $status{'tgt-unalignment-rate'};

	if ( !( $self->filtering_options eq 'none' ) ) {
		my $f_str = $self->filtering_options;
		if ( $f_str eq '1-1' ) {
			if ( !$status{'1-1'} ) {
				print "removing bundle\n";
				$bundle->remove();
			}
			else {
				if ( ( $src_una_rate > $self->max_src_unalign_rate ) && ( $tgt_una_rate > $self->max_tgt_unalign_rate ) ) {
					print "removing bundle\n";
					$bundle->remove();
				}
			}
		}
		elsif ( $f_str eq '1-1-perfect' ) {
			if ( !$status{'1-1-perfect'} ) {
				print "removing bundle\n";
				$bundle->remove();
			}
		}
	}
	elsif ( $self->filtering_options eq 'none' ) {
		my $src_una_rate = $status{'src-unalignment-rate'};
		my $tgt_una_rate = $status{'tgt-unalignment-rate'};
		if ( ( $src_una_rate > $self->max_src_unalign_rate ) && ( $tgt_una_rate > $self->max_tgt_unalign_rate ) ) {
			print "removing bundle\n";
			$bundle->remove();
		}
	}
}

sub get_alignment_status {
	my ( $self, $src_tree, $tgt_tree ) = @_;

	my %status = (
		'1-1'                  => 0,
		'1-1-perfect'          => 0,
		'src-unalignment-rate' => 1,
		'tgt-unalignment-rate' => 1,
	);

	my $alignment_stats = Treex::Block::Print::AlignmentStatistics->new(
		{
			source_language     => $self->source_language,
			source_selector     => $self->source_selector,
			language            => $self->language,
			selector            => $self->selector,
			alignment_type      => $self->alignment_type,
			alignment_direction => $self->alignment_direction,
			_file_handle	=> \*STDOUT,
			statistics => 1,
		}
	);
	my $local_stat_rf = $alignment_stats->get_local_stat($src_tree, $tgt_tree);
	
	# fill the alignment status
	if ( ( $local_stat_rf->{'many_to_one'} == 0 ) && ( $local_stat_rf->{'one_to_many'} == 0 ) ) {
		$status{'1-1'} = 1;
		if ( ( $local_stat_rf->{'src_unaligned'} == 0 ) && ( $local_stat_rf->{'tgt_unaligned'} == 0 ) )	{
			$status{'1-1-perfect'} = 1;
		}
	}
	$status{'src-unalignment-rate'} = $local_stat_rf->{'src_unaligned'} / $local_stat_rf->{'src_len'};	
	$status{'tgt-unalignment-rate'} = $local_stat_rf->{'tgt_unaligned'} / $local_stat_rf->{'tgt_len'};	

#	my $out_string = sprintf("%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%1d\t%1d\t%.2f\t%.2f", $local_stat_rf->{'src_len'}, $local_stat_rf->{'tgt_len'}, $local_stat_rf->{'src_unaligned'}, $local_stat_rf->{'tgt_unaligned'}, $local_stat_rf->{'one_to_one'},   $local_stat_rf->{'one_to_many'}, $local_stat_rf->{'many_to_one'}, $status{'1-1'}, $status{'1-1-perfect'}, $status{'src-unalignment-rate'}, $status{'tgt-unalignment-rate'});
#	print $out_string . "\n";

	return %status;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::FilterTreesByAlignment - filter trees based on alignment criteria

=head1 SYNOPSIS

	# keep only trees in which nodes ( between src and tgt ) can have only 1-1 alignments
	treex -Lta Util::SetGlobal selector='' Read::Treex from='test.treex.gz' A2A::FilterTreesByAlignment source_language=en source_selector='GT'  alignment_type='gloss' alignment_direction='src2trg' filtering_options='1-1'

	# keep only trees in which nodes ( between src and tgt ) can have only 1-1 alignments, further control by unalignment rates
	treex -Lta Util::SetGlobal selector='' Read::Treex from='test.treex.gz' A2A::FilterTreesByAlignment source_language=en source_selector='GT'  alignment_type='gloss' alignment_direction='src2trg' filtering_options='1-1' max_src_unalign_rate=0.25 max_tgt_unalign_rate=0.25

	# keep only trees in which nodes ( between src and tgt ) can have only 1-1 alignments, unaligned nodes are not permitted
	treex -Lta Util::SetGlobal selector='' Read::Treex from='test.treex.gz' A2A::FilterTreesByAlignment source_language=en source_selector='GT'  alignment_type='gloss' alignment_direction='src2trg' filtering_options='1-1-perfect'
	

=head1 DESCRIPTION

This block assumes each bundle has parallel sentences/trees and nodes are word aligned. The block filters trees based on alignment criteria.  


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.