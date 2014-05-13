package Treex::Block::Print::BranchingFreq;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $_total_left_modifiers = 0.0;
my $_total_right_modifiers = 0.0;

sub process_anode {
    my $self      = shift;
    my $anode     = shift;
	my $p = $anode->get_parent;
	if ($p->ord != 0) {
		if ($anode->ord < $p->ord) {
			$_total_left_modifiers++;
		}
		else {
			$_total_right_modifiers++;
		}
	}    
}

sub process_end {
	my $self = shift;
	my $left_modifier_perc;
	my $right_modifier_perc;
	my $total = $_total_left_modifiers + $_total_right_modifiers;
	$left_modifier_perc = ($_total_left_modifiers / $total) * 100.0;
	$right_modifier_perc = ($_total_right_modifiers / $total) * 100.0;
	my $out_string1 = sprintf("%-28s\t-\t%05.2f", "Left modifier percentage", $left_modifier_perc);
	my $out_string2 = sprintf("%-28s\t-\t%05.2f", "Right modifier percentage", $right_modifier_perc);
	print $out_string1 . "\n";
	print $out_string2 . "\n";
}

1;

__END__

=head1 NAME

Treex::Block::Print::BranchingFreq - prints frequency of left and right modifiers

=head1 DESCRIPTION

This block prints prints the percentage of nodes that modify nodes to the left and right. This block is useful to understand to what extent the trees are left branching and right branching. 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE 

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.