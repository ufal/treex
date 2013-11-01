package Treex::Block::A2A::FilterTreesByAlignment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

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

# other options: '1-1', '1-1-perfect'
has filtering_options	=> (
	is => 'ro',
	isa => 'Str',
	default => 'none'
);

has max_src_unalign_rate 	=> ( is => 'ro', isa => 'Num', default => 0.5 );
has max_tgt_unalign_rate 	=> ( is => 'ro', isa => 'Num', default => 0.5 );


sub process_bundle {
	
	my ($self, $bundle) = @_;
	
	my @all_zones = $bundle->get_all_zones();		

	my $src_zone = $bundle->get_zone($self->source_language, $self->source_selector);
	my $tgt_zone = $bundle->get_zone($self->language, $self->selector);
	my $src_tree = $src_zone->get_tree($self->layer);
	my $tgt_tree = $tgt_zone->get_tree($self->layer);
	
	my %status = $self->get_alignment_status($src_tree, $tgt_tree);
	
	if (!($self->filtering_options eq 'none')) {
		my $f_str = $self->filtering_options; 
		if ($f_str eq '1-1') {
			if (!$status{'1-1'}) {
				print "removing bundle\n";
				$bundle->remove();
			} 
			else {
				my $src_una_rate = $status{'src-unalignment-rate'};
				my $tgt_una_rate = $status{'tgt-unalignment-rate'};
				if (($src_una_rate > $self->max_src_unalign_rate) && ($tgt_una_rate > $self->max_tgt_unalign_rate)) {
					print "removing bundle\n";
					$bundle->remove();
				}				
			}			
		}
		elsif ($f_str eq '1-1-perfect') {
			if (!$status{'1-1-perfect'}) {
				print "removing bundle\n";
				$bundle->remove();
			}
		}
	}
}



sub get_alignment_status {
	my ($self, $src_tree, $tgt_tree) = @_;
	
	my %status = (	
		'1-1' => 0, 
		'1-1-perfect' => 0,
		'src-unalignment-rate' => 1,
		'tgt-unalignment-rate' => 1,
	);	

	my %local_stat = ();

	my @one_to_one_s = ();
	my @one_to_one_t = ();
	my @one_to_many_s = ();
	my @one_to_many_t = ();
	my @many_to_one_s = ();	
	my @many_to_one_t = ();	
	
	$local_stat{'src_unaligned'} = 0;
	$local_stat{'tgt_unaligned'} = 0;
	$local_stat{'one_to_one'} = 0;
	$local_stat{'one_to_many'} = 0;
	$local_stat{'many_to_one'} = 0;	
	$local_stat{'src_len'} = 0;
	$local_stat{'tgt_len'} = 0;	
	
	my @src_nodes = $src_tree->get_descendants({ordered=>1});
	my @tgt_nodes = $tgt_tree->get_descendants({ordered=>1});
	
	if ($self->alignment_direction eq 'src2trg') {
		foreach my $i (0..$#src_nodes) {
			my @aligned_nodes = $src_nodes[$i]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
			if (@aligned_nodes) {
				if (scalar(@aligned_nodes) > 1) {
					$local_stat{'one_to_many'}++;
					push @one_to_many_s, $src_nodes[$i];
					push @one_to_many_t, \@aligned_nodes;
				}
				elsif (scalar(@aligned_nodes) == 1) {
					my @referring_nodes = grep {$_->is_aligned_to($aligned_nodes[0], '^' . $self->alignment_type . '$')} $aligned_nodes[0]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
					if (scalar(@referring_nodes) == 1) {
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
		foreach my $j (0..$#tgt_nodes) {
			my @referring_nodes = grep {$_->is_aligned_to($tgt_nodes[$j], '^' . $self->alignment_type . '$')} $tgt_nodes[$j]->get_referencing_nodes('alignment', $self->source_language, $self->source_selector);
			if (!@referring_nodes) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@referring_nodes) {
				if ($#referring_nodes > 0) {
					my $is_m_to_1 = 1;
					foreach my $rn (@referring_nodes) {
						my @aligned_nodes = $rn->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
						if (scalar(@aligned_nodes) != 1) {
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
		foreach my $i (0..$#src_nodes) {
			my @referring_nodes = grep {$_->is_aligned_to($src_nodes[$i], '^' . $self->alignment_type . '$')} $src_nodes[$i]->get_referencing_nodes('alignment', $self->language, $self->selector);
			if (@referring_nodes) {
				if (scalar(@referring_nodes) > 1) {
					$local_stat{'one_to_many'}++;
					push @one_to_many_s, $src_nodes[$i];
					push @one_to_many_t, \@referring_nodes;					
				}	
				elsif (scalar(@referring_nodes) == 1) {
					my @aligned_nodes = $referring_nodes[0]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->source_language, $self->source_selector);
					if (scalar(@aligned_nodes) == 1) {
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
		foreach my $j (0..$#tgt_nodes) {
			my @aligned_nodes = $tgt_nodes[$j]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->source_language, $self->source_selector);
			if (!@aligned_nodes) {
				$local_stat{'tgt_unaligned'}++;
			}
			if (@aligned_nodes) {
				if ($#aligned_nodes > 0) {
					my $is_m_to_1 = 1;
					foreach my $an (@aligned_nodes) {
						my @referring_nodes = grep {$_->is_aligned_to($an, '^' . $self->alignment_type . '$')} $an->get_referencing_nodes('alignment', $self->language, $self->selector);
						if (scalar(@referring_nodes != 1)) {
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
	
	# fill the alignment status
	if ( ($local_stat{'many_to_one'} == 0) && ($local_stat{'one_to_many'} == 0) ) {
		$status{'1-1'} = 1;
		if ( ($local_stat{'src_unaligned'} == 0) && ($local_stat{'tgt_unaligned'} == 0) ) {
			$status{'1-1-perfect'} = 1;
		}
		else {
			$status{'src-unalignment-rate'} = $local_stat{'src_unaligned'} / scalar(@src_nodes);
			  
			$status{'tgt-unalignment-rate'} = $local_stat{'tgt_unaligned'} / scalar(@tgt_nodes);			
		}
	}
	
	#my $out_string = sprintf("%1d\t%1d\t%.2f\t%.2f", $status{'1-1'}, $status{'1-1-perfect'}, $status{'src-unalignment-rate'}, $status{'tgt-unalignment-rate'});
	#print $out_string . "\n";
	
	return %status;
}

1;
