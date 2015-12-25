package Treex::Block::Print::AlignmentStatistics;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

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
has _stats => ( is => 'ro', default => sub { {} } );
has one_to_one  => ( isa => 'Bool', is => 'rw', default => 0 );
has one_to_many => ( isa => 'Bool', is => 'rw', default => 0 );
has many_to_one => ( isa => 'Bool', is => 'rw', default => 0 );
has statistics  => ( isa => 'Bool', is => 'rw', default => 0 );

sub process_zone {
	my ( $self, $zone ) = @_;
	my $source_zone =
	  $zone->get_bundle()
	  ->get_zone( $self->source_language, $self->source_selector );
	my ( $tree, $source_tree ) =
	  map { $_->get_tree( $self->layer ) } ( $zone, $source_zone );
	my $local_stat_rf = $self->get_local_stat( $source_tree, $tree );
	$self->print_alignment_info($source_tree, $tree, $local_stat_rf);
}

sub get_local_stat {

	my ( $self, $src_tree, $tgt_tree ) = @_;

	my %local_stat = ();

	my @one_to_one_s  = ();
	my @one_to_one_t  = ();
	my @one_to_many_s = ();
	my @one_to_many_t = ();
	my @many_to_one_s = ();
	my @many_to_one_t = ();

	$local_stat{'src_unaligned'} = 0;
	$local_stat{'tgt_unaligned'} = 0;
	$local_stat{'one_to_one'}    = 0;
	$local_stat{'one_to_many'}   = 0;
	$local_stat{'many_to_one'}   = 0;
	$local_stat{'src_len'}       = 0;
	$local_stat{'tgt_len'}       = 0;

	my @src_nodes = $src_tree->get_descendants( { ordered => 1 } );
	my @tgt_nodes = $tgt_tree->get_descendants( { ordered => 1 } );
	
	$local_stat{'src_len'} = scalar(@src_nodes);
	$local_stat{'tgt_len'} = scalar(@tgt_nodes);

	if ( $self->alignment_direction eq 'src2trg' ) {
		foreach my $i ( 0 .. $#src_nodes ) {
			my @aligned_nodes =
			  $src_nodes[$i]
			  ->get_aligned_nodes_of_type( '^' . $self->alignment_type . '$',
				$self->language, $self->selector );
			if (@aligned_nodes) {
				if ( scalar(@aligned_nodes) > 1 ) {
					$local_stat{'one_to_many'}++;
					push @one_to_many_s, $src_nodes[$i];
					push @one_to_many_t, \@aligned_nodes;
				}
				elsif ( scalar(@aligned_nodes) == 1 ) {
					my @referring_nodes = grep {
						$_->is_aligned_to( $aligned_nodes[0],
							{rel_types => ['^'.$self->alignment_type.'$']} )
					  } $aligned_nodes[0]->get_referencing_nodes( 'alignment',
						$self->source_language, $self->source_selector );
					if ( scalar(@referring_nodes) == 1 ) {
						$local_stat{'one_to_one'}++;
						push @one_to_one_s, $src_nodes[$i];
						push @one_to_one_t, $aligned_nodes[0];
					}
				}
			}
			else {
				$local_stat{'src_unaligned'}++;
			}
		}
		foreach my $j ( 0 .. $#tgt_nodes ) {
			my @referring_nodes = grep {
				$_->is_aligned_to( $tgt_nodes[$j],
					{rel_types => ['^'.$self->alignment_type.'$']} )
			  } $tgt_nodes[$j]
			  ->get_referencing_nodes( 'alignment', $self->source_language,
				$self->source_selector );
			if ( !@referring_nodes ) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@referring_nodes) {
				if ( $#referring_nodes > 0 ) {
					my $is_m_to_1 = 1;
					foreach my $rn (@referring_nodes) {
						my @aligned_nodes = $rn->get_aligned_nodes_of_type(
							'^' . $self->alignment_type . '$',
							$self->language, $self->selector );
						if ( scalar(@aligned_nodes) != 1 ) {
							$is_m_to_1 = 0;
							last;
						}
					}
					if ($is_m_to_1) {
						$local_stat{'many_to_one'}++;
						push @many_to_one_s, \@referring_nodes;
						push @many_to_one_t, $tgt_nodes[$j];
					}
				}
			}
		}
	}
	else {
		foreach my $i ( 0 .. $#src_nodes ) {
			my @referring_nodes = grep {
				$_->is_aligned_to( $src_nodes[$i],
					{rel_types => ['^'.$self->alignment_type.'$']} )
			  } $src_nodes[$i]
			  ->get_referencing_nodes( 'alignment', $self->language,
				$self->selector );
			if (@referring_nodes) {
				if ( scalar(@referring_nodes) > 1 ) {
					$local_stat{'one_to_many'}++;
					push @one_to_many_s, $src_nodes[$i];
					push @one_to_many_t, \@referring_nodes;
				}
				elsif ( scalar(@referring_nodes) == 1 ) {
					my @aligned_nodes =
					  $referring_nodes[0]->get_aligned_nodes_of_type(
						'^' . $self->alignment_type . '$',
						$self->source_language, $self->source_selector );
					if ( scalar(@aligned_nodes) == 1 ) {
						$local_stat{'one_to_one'}++;
						push @one_to_one_s, $src_nodes[$i];
						push @one_to_one_t, $referring_nodes[0];
					}
				}
			}
			else {
				$local_stat{'src_unaligned'}++;
			}
		}
		foreach my $j ( 0 .. $#tgt_nodes ) {
			my @aligned_nodes =
			  $tgt_nodes[$j]
			  ->get_aligned_nodes_of_type( '^' . $self->alignment_type . '$',
				$self->source_language, $self->source_selector );
			if ( !@aligned_nodes ) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@aligned_nodes) {
				if ( $#aligned_nodes > 0 ) {
					my $is_m_to_1 = 1;
					foreach my $an (@aligned_nodes) {
						my @referring_nodes = grep {
							$_->is_aligned_to( $an,
								{rel_types => ['^'.$self->alignment_type.'$']} )
						  } $an->get_referencing_nodes( 'alignment',
							$self->language, $self->selector );
						if ( scalar( @referring_nodes != 1 ) ) {
							$is_m_to_1 = 0;
							last;
						}
					}
					if ($is_m_to_1) {
						$local_stat{'many_to_one'}++;
						push @many_to_one_s, \@aligned_nodes;
						push @many_to_one_t, $tgt_nodes[$j];
					}
				}
			}
		}
	}
	if ( !exists $self->_stats->{'src_id'} ) {
		my @tmp = ( $src_tree->id );
		$self->_stats->{'src_id'} = \@tmp;
	}
	else {
		my @tmp = @{ $self->_stats->{'src_id'} };
		push @tmp, $src_tree->id;
		$self->_stats->{'src_id'} = \@tmp;
	}

	if ( !exists $self->_stats->{'tgt_id'} ) {
		my @tmp = ( $tgt_tree->id );
		$self->_stats->{'tgt_id'} = \@tmp;
	}
	else {
		my @tmp = @{ $self->_stats->{'tgt_id'} };
		push @tmp, $tgt_tree->id;
		$self->_stats->{'tgt_id'} = \@tmp;
	}

	if ( exists $self->_stats->{'src_unaligned'} ) {
		$self->_stats->{'src_unaligned'} += $local_stat{'src_unaligned'};
	}
	else {
		$self->_stats->{'src_unaligned'} = $local_stat{'src_unaligned'};
	}
	if ( exists $self->_stats->{'tgt_unaligned'} ) {
		$self->_stats->{'tgt_unaligned'} += $local_stat{'tgt_unaligned'};
	}
	else {
		$self->_stats->{'tgt_unaligned'} = $local_stat{'tgt_unaligned'};
	}
	if ( exists $self->_stats->{'src_len'} ) {
		$self->_stats->{'src_len'} += scalar(@src_nodes);
	}
	else {
		$self->_stats->{'src_len'} = scalar(@src_nodes);
	}
	if ( exists $self->_stats->{'tgt_len'} ) {
		$self->_stats->{'tgt_len'} += scalar(@tgt_nodes);
	}
	else {
		$self->_stats->{'tgt_len'} = scalar(@tgt_nodes);
	}
	if ( exists $self->_stats->{'one_to_one'} ) {
		$self->_stats->{'one_to_one'} += $local_stat{'one_to_one'};
	}
	else {
		$self->_stats->{'one_to_one'} = $local_stat{'one_to_one'};
	}
	if ( exists $self->_stats->{'one_to_many'} ) {
		$self->_stats->{'one_to_many'} += $local_stat{'one_to_many'};
	}
	else {
		$self->_stats->{'one_to_many'} = $local_stat{'one_to_many'};
	}
	if ( exists $self->_stats->{'many_to_one'} ) {
		$self->_stats->{'many_to_one'} += $local_stat{'many_to_one'};
	}
	else {
		$self->_stats->{'many_to_one'} = $local_stat{'many_to_one'};
	}

	$local_stat{'1-1-src-nodes-rf'} = \@one_to_one_s;
	$local_stat{'1-1-tgt-nodes-rf'} = \@one_to_one_t;
	$local_stat{'1-M-src-nodes-rf'} = \@one_to_many_s;
	$local_stat{'1-M-tgt-nodes-rf'} = \@one_to_many_t;
	$local_stat{'M-1-src-nodes-rf'} = \@many_to_one_s;
	$local_stat{'M-1-tgt-nodes-rf'} = \@many_to_one_t;

	return \%local_stat;

}

sub print_alignment_info {
	my ( $self, $src_tree, $tgt_tree, $local_stat_rf ) = @_;

	my %local_stat    = %$local_stat_rf;
	my @one_to_one_s  = @{ $local_stat{'1-1-src-nodes-rf'} };
	my @one_to_one_t  = @{ $local_stat{'1-1-tgt-nodes-rf'} };
	my @one_to_many_s = @{ $local_stat{'1-M-src-nodes-rf'} };
	my @one_to_many_t = @{ $local_stat{'1-M-tgt-nodes-rf'} };
	my @many_to_one_s = @{ $local_stat{'M-1-src-nodes-rf'} };
	my @many_to_one_t = @{ $local_stat{'M-1-tgt-nodes-rf'} };
	
	my @src_nodes = $src_tree->get_descendants( { ordered => 1 } );
	my @tgt_nodes = $tgt_tree->get_descendants( { ordered => 1 } );

	if ( $self->one_to_one ) {
		my $sid = $src_tree->id;
		my $tid = $tgt_tree->id;
		foreach my $i ( 0 .. $#one_to_one_s ) {
			if ( $i != 0 ) {
				$sid = '';
				$tid = '';
			}
			my $out_string = sprintf(
				"%30s\t%40s\t%20s\t%20s\t%4d\t%4d",
				$sid, $tid,
				$one_to_one_s[$i]->form,
				$one_to_one_t[$i]->form,
				$one_to_one_s[$i]->ord,
				$one_to_one_t[$i]->ord
			);
			print { $self->_file_handle } $out_string . "\n";
		}
	}
	if ( $self->one_to_many ) {
		my $sid = $src_tree->id;
		my $tid = $tgt_tree->id;
		foreach my $i ( 0 .. $#one_to_many_s ) {
			if ( $i != 0 ) {
				$sid = '';
				$tid = '';
			}
			my @tmp_one_many_t = @{ $one_to_many_t[$i] };
			foreach my $j ( 0 .. $#tmp_one_many_t ) {
				my $out_string;
				if ( ( $i == 0 ) && ( $j == 0 ) ) {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4d\t%-4d",
						$sid,                     $tid,
						$one_to_many_s[$i]->form, $tmp_one_many_t[$j]->form,
						$one_to_many_s[$i]->ord,  $tmp_one_many_t[$j]->ord
					);
				}
				elsif ( ( $i != 0 ) && ( $j == 0 ) ) {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4d\t%-4d",
						'',                       '',
						$one_to_many_s[$i]->form, $tmp_one_many_t[$j]->form,
						$one_to_many_s[$i]->ord,  $tmp_one_many_t[$j]->ord
					);
				}
				else {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4s\t%-4d",
						'', '', '', $tmp_one_many_t[$j]->form,
						'', $tmp_one_many_t[$j]->ord
					);
				}
				print { $self->_file_handle } $out_string . "\n";
			}
		}
	}
	if ( $self->many_to_one ) {
		my $sid = $src_tree->id;
		my $tid = $tgt_tree->id;
		foreach my $i ( 0 .. $#many_to_one_s ) {
			if ( $i != 0 ) {
				$sid = '';
				$tid = '';
			}
			my @tmp_many_one_s = @{ $many_to_one_s[$i] };
			foreach my $j ( 0 .. $#tmp_many_one_s ) {
				my $out_string;
				if ( ( $i == 0 ) && ( $j == 0 ) ) {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4d\t%-4d",
						$sid,                      $tid,
						$tmp_many_one_s[$j]->form, $many_to_one_t[$i]->form,
						$tmp_many_one_s[$j]->ord,  $many_to_one_t[$i]->ord
					);
				}
				elsif ( ( $i != 0 ) && ( $j == 0 ) ) {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4d\t%-4d",
						'',                        '',
						$tmp_many_one_s[$j]->form, $many_to_one_t[$i]->form,
						$tmp_many_one_s[$j]->ord,  $many_to_one_t[$i]->ord
					);
				}
				else {
					$out_string = sprintf(
						"%30s\t%40s\t%-20s\t%-20s\t%-4d\t%-4s",
						'', '', $tmp_many_one_s[$j]->form,
						'', $tmp_many_one_s[$j]->ord, ''
					);
				}
				print { $self->_file_handle } $out_string . "\n";
			}
		}
	}
	if ( $self->statistics ) {
		my $out_string = sprintf(
			"%20s\t%20s\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d\t%4d",
			( substr $src_tree->id, 0, 20 ), ( substr $tgt_tree->id, 0, 20 ),
			scalar(@src_nodes),           scalar(@tgt_nodes),
			$local_stat{'src_unaligned'}, $local_stat{'tgt_unaligned'},
			$local_stat{'one_to_one'},    $local_stat{'one_to_many'},
			$local_stat{'many_to_one'}
		);
		print { $self->_file_handle } $out_string . "\n";
	}
}

sub process_end {
	my $self = shift;
	if ( $self->statistics ) {
		my $num_trees = 0;
		if ( exists $self->_stats->{'src_id'} ) {
			my @tmp = @{ $self->_stats->{'src_id'} };
			$num_trees = scalar(@tmp);
		}
		my $out1_string = sprintf(
			"%10s\t%10s\t%10s\t%10s\t%14s\t%14s\t%4s\t%4s\t%4s",
			"#src_trees", "#tgt_trees",     "#src_nodes",
			"#tgt_nodes", '#src_unaligned', '#tgt_unaligned',
			'#1-1',       '#1-M',           '#M-1'
		);
		print { $self->_file_handle } $out1_string . "\n";
		my $out_string = sprintf(
			"%10d\t%10d\t%10d\t%10d\t%14d\t%14d\t%4d\t%4d\t%4d",
			$num_trees,
			$num_trees,
			$self->_stats->{'src_len'},
			$self->_stats->{'tgt_len'},
			$self->_stats->{'src_unaligned'},
			$self->_stats->{'tgt_unaligned'},
			$self->_stats->{'one_to_one'},
			$self->_stats->{'one_to_many'},
			$self->_stats->{'many_to_one'}
		);
		print { $self->_file_handle } $out_string . "\n";
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::AlignmentStatistics - prints useful information and summary statistics between aligned sentences


=head1 SYNOPSIS

	# prints one to one alignment between sentences 
	# target=ta, target selector='autoalign', source=en, source selector=''
	treex -Lta Util::SetGlobal selector='autoalign' Read::Treex from='test.treex.gz' Print::AlignmentStatistics source_language='en' source_selector='' alignment_direction='src2trg' one_to_one=1

	# prints alignment statistics with summary at the end 
	# target=ta, target selector='autoalign', source=en, source selector=''
	treex -Lta Util::SetGlobal selector='autoalign' Read::Treex from='test.treex.gz' Print::AlignmentStatistics source_language='en' source_selector='' alignment_direction='src2trg' statistics=1

=head1 DESCRIPTION

This block prints alignment information between two sentences in a human readable format for further analysis. 
 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


