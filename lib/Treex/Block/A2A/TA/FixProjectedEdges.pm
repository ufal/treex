package Treex::Block::A2A::TA::FixProjectedEdges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'projected_from' => (isa => 'Str', is => 'ro', default => 'en');

sub process_atree {
	my ($self, $root) = @_;	
	$self->fix_en_projected_edges($root) if $self->projected_from eq 'en';
}

sub fix_en_projected_edges {
	my ($self, $root) = @_;
	my @desc =  $root->get_descendants( { ordered => 1 } );

	# (i) Attach PP to nearest verbs
	# ------------------------------
	# In Tamil, postpositional phrases (PP) tend to be attached 
	# to nearest clausal heads or verb phrases. 
	# -------------------------------
	foreach my $n (@desc) {
		my $p = $n->get_parent();
		if (($n->tag =~ /^P/) && ($p != $n) && ($p != $root) && ($p->tag !~ /^V/)) {
			my $prev = $p;
			my $prev_par = $prev->get_parent();			
			while (($prev_par != $prev) && ($prev_par != $root)) {
				if ($prev_par->tag !~ /^V/) {
					$prev = $prev_par;
					$prev_par = $prev_par->get_parent();					
				}
				else {
					$n->set_parent($prev_par);
					last;
				}
			}			
		} 
	}
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::FixProjectedEdges - Implements language specific rules to fix projection errors

=head1 SYNOPSIS

A2A::TA::FixProjectedEdges projected_from='en'

=head1 DESCRIPTION

This block fixes some of the systematic incorrect edge attachments (mainly due to annotation style) in the projection.
 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
