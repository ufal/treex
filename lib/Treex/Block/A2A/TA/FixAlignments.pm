package Treex::Block::A2A::TA::FixAlignments;
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

sub process_zone {
    my ( $self, $zone ) = @_;
    my $source_zone = $zone->get_bundle()->get_zone( $self->source_language, '');
    my ($tree, $source_tree) = map {$_->get_tree($self->layer)} ($zone, $source_zone);
    $self->delete_alignment_links($source_tree, $tree);        
}

sub fix_one_to_one {
	my ($self, $src_root, $tgt_root) = @_;
	return;
}

sub fix_one_to_many {
	my ($self, $src_root, $tgt_root) = @_;
	return;	
}

sub fix_many_to_one {
	my ($self, $src_root, $tgt_root) = @_;
	return;		
}

sub delete_alignment_links {
	my ($self, $src_root, $tgt_root) = @_;
	if ($self->source_language eq 'en') {
		my @src_nodes = $src_root->get_descendants({ordered=>1});
		foreach my $i (0..$#src_nodes) {
			if ($self->alignment_direction eq 'trg2src') {
				my @referring_nodes = grep {
                    $_->is_directed_aligned_to($src_nodes[$i], { rel_types => ['^'.$self->alignment_type.'$']})
                } $src_nodes[$i]->get_referencing_nodes('alignment', $self->language, $self->selector);	
				if (@referring_nodes) {
					# delete alignments for some English function words that do not have 
					# translation equivalents
					if ($src_nodes[$i]->form =~ /^(a|an|the|at|for|in|of|on|to)$/i) {
						foreach my $rn (@referring_nodes) {
							print "Deleting alignment between: [ " . $src_nodes[$i]->form . ", " . $rn->form . " ]\n";
							$rn->delete_aligned_node($src_nodes[$i], $self->alignment_type);
						}
					}
					# (ii) remove alignment if a punctuation is aligned to a form on the other side
					foreach my $rn (@referring_nodes) {
						if ((($src_nodes[$i] =~ /^\p{IsP}$/) && ($rn->form !~ /^\p{IsP}$/)) || (($src_nodes[$i] !~ /^\p{IsP}$/) && ($rn->form =~ /^\p{IsP}$/))) {
							$src_nodes[$i]->delete_aligned_node($rn, $self->alignment_type);
						}
					}					
				}				
			}
			else {
				my @aligned_nodes = $src_nodes[$i]->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
				if (@aligned_nodes) {					
					# (i) delete alignments for some English function words that do not have 
					# translation equivalents					
					if ($src_nodes[$i]->form =~ /^(a|an|the|at|for|in|of|on|to)$/i) {					
						foreach my $an (@aligned_nodes) {
							$src_nodes[$i]->delete_aligned_node($an, $self->alignment_type);
						}
					}
					# (ii) remove alignment if a punctuation is aligned to a form on the other side
					foreach my $an (@aligned_nodes) {
						if ((($src_nodes[$i] =~ /^\p{IsP}$/) && ($an->form !~ /^\p{IsP}$/)) || (($src_nodes[$i] !~ /^\p{IsP}$/) && ($an->form =~ /^\p{IsP}$/))) {
							$src_nodes[$i]->delete_aligned_node($an, $self->alignment_type);
						}
					}						
				}		
			}		
		}
	}
}


1;
