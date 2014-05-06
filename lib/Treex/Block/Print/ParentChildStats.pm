package Treex::Block::Print::ParentChildStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'deprel_attribute' => ( is => 'rw', isa => 'Str', default => 'afun' );
has 'pos_attribute'    => ( is => 'rw', isa => 'Str', default => 'tag' );

my %_tag_stats        = ();
my %_deprel_stats     = ();
my %_deprel_tag_stats = ();

sub process_anode {
	my $self  = shift;
	my $anode = shift;
	my $par   = $anode->get_parent();
	my $parent_tag;
	my $parent_rel;

	# node
	my $node_tag = $anode->get_attr( $self->pos_attribute );
	my $node_rel = $anode->get_attr( $self->deprel_attribute );
	
	#print $node_tag . $node_rel . "\t=>\t" . $anode->ord . "\t\n";

	# parent
	if ( $par->ord == 0 ) {
		$parent_tag = 'ROOT';
		$parent_rel = 'ROOT';
	}
	else {
		$parent_tag = $par->get_attr( $self->pos_attribute );
		$parent_rel = $par->get_attr( $self->deprel_attribute );
	}
	$_tag_stats{ $parent_tag . '=>' . $node_tag }++;
	$_deprel_stats{ $parent_rel . '=>' . $node_rel }++;
	$_deprel_tag_stats{ $parent_rel . ' / '
		  . $parent_tag . '=>'
		  . $node_rel . ' / '
		  . $node_tag }++;
}

sub process_end {

	print "******************************************\n";
	print "Parent/child deprel statistics\n";
	print "******************************************\n";
	foreach my $k ( sort { $_deprel_stats{$b} <=> $_deprel_stats{$a} } keys %_deprel_stats) {
		my @for_format = split "=>", $k;
		my $str_line = sprintf("[ %8s / %-8s ] : %-5d", $for_format[0], $for_format[1], $_deprel_stats{$k});
		print $str_line . "\n";
	}
	print "\n";
	print "******************************************\n";
	print "Parent/child tag statistics\n";
	print "******************************************\n";
	foreach my $k ( sort { $_tag_stats{$b} <=> $_tag_stats{$a} } keys %_tag_stats) {
		my @for_format = split "=>", $k;
		my $str_line = sprintf("[ %10s / %-10s ] : %-5d", $for_format[0], $for_format[1], $_tag_stats{$k});
		print $str_line . "\n";
	}

	print "******************************************\n";
	print "Parent/child deprel/tag statistics\n";
	print "******************************************\n";
	foreach my $k ( sort { $_deprel_tag_stats{$b} <=> $_deprel_tag_stats{$a} } keys %_deprel_tag_stats) {
		my @for_format = split "=>", $k;
		my @for_format1 = split ' / ', $for_format[0];
		my @for_format2 = split ' / ', $for_format[1];
		my $str_line = sprintf("[ %8s / %-8s , %10s / %-10s ] : %-5d", $for_format1[0], $for_format2[0], $for_format1[1],  $for_format2[1], $_deprel_tag_stats{$k});
		print $str_line . "\n";
	}		
}

1;

__END__

=head1 NAME

Treex::Block::Print::ParentChildStats - prints frequency of parent/child afun and tag attributes

=head1 DESCRIPTION

This block prints frequency of edges based on parent/child afun and tag attributes. In other words, the frequency information reveal the pattern of parent/child tags as well as parent/child afuns.


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE 

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

