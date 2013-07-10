package Treex::Block::Eval::AER;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# source language
has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

# alignment (gold) in target language 
has 'gold_alignment_type' => (isa => 'Str', is => 'ro', default => 'alignment');
has 'gold_selector' => (isa => 'Str', is => 'ro', required => 1);

# alignment (hypothesis) in target language
has 'target_language' => (isa => 'Str', is => 'ro', required => 1);
has 'target_selector' => (isa => 'Str', is => 'ro', required => 1);
has 'target_alignment_type' => (isa => 'Str', is => 'ro', default => 'berkeley');

# |A ^ S| - number of proposed edges matching 'sure' gold edges
my $sure_intersection = 0.0;

# |A ^ P| - number of proposed edges matching 'possible' gold edges
my $possible_intersection = 0.0;

# |A| - number of proposed edges
my $proposed_edges = 0.0;

# |S| - number of 'sure' edges
my $sure_edges = 0.0;

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );	
	foreach my $node (@nodes) {
		my @target_nodes = $node->get_aligned_nodes_of_type('^' . $self->target_alignment_type . '$', $self->target_language, $self->target_selector);
		my @gold_nodes = $node->get_aligned_nodes_of_type('^' . $self->gold_alignment_type . '$', $self->target_language, $self->gold_selector);
		$proposed_edges += scalar(@target_nodes) if @target_nodes;
		$sure_edges += scalar(@gold_nodes) if @gold_nodes;
		if ((scalar(@target_nodes) > 0) && (scalar(@gold_nodes) > 0)) {
			my %g = ();
			my %p = ();
			map{$p{$node->ord . '-' . $_->ord}++;}@target_nodes;
			map{$g{$node->ord . '-' . $_->ord}++;}@gold_nodes;
			foreach my $k (keys %p) {
				$sure_intersection++ if (exists $g{$k});
			}
		} 
	}		
}

sub process_end {
    my ($self) = @_; 

	# --------------------------------
	# Alignment Error Rate (AER)
	# --------------------------------
    #			  |A ^ S| + |A ^ P|
    # AER = 1 -   ------------------
    #                 |A| + |S| 
	# --------------------------------
	my $AER = 100;
	my $den = $proposed_edges + $sure_edges;
	# 'possible_intersection' is at least 'sure_intersection'
	# TODO: should replace with the correct estimate
	my $num = $sure_intersection * 2;
	if ($den > 0) {
		$AER = (1 - ($num / $den)) * 100;
	}
	print "Alignment Error Rate (AER)\t:\t$AER\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Eval::AER - Calculates Alignment Error Rate (AER) between manual and hypothesis alignments.

=head1 SYNOPSIS

 # To calculate AER between two different alignments between source and target languages 
 # source language: language='en' selector=''
 # target language: target_language='ta' 
 # 1st alignment (gold) in target language: gold_selector='' gold_alignment_type='human' 
 # 2nd alignment (hypothesis) in target language: target_selector='berk' target_alignment_type='berkeley'
 treex -Len Util::SetGlobal selector='' Eval::AER gold_selector='' gold_alignment_type='human' target_language='ta' target_selector='berk' target_alignment_type='berkeley'

=head1 DESCRIPTION

This block calculates Alignment Error Rate (AER) between two alignments. 

=head1 TODO

1. handle 'possible' alignments

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
