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
	
	# ------------------------------
	# Rules for improving projection
	#-------------------------------

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
	
	# (ii) In Tamil verbs of the form 'Nominal + Auxiliary', 'Auxiliary' should be the head and 
	# 'nominal' should be the child.
	@desc =  $root->get_descendants( { ordered => 1 } );
	foreach my $n (@desc) {
		my $p = $n->get_parent();
		if (($n->tag =~ /^V[rtuwRTUW]/) && ($p != $root) && ($p->tag =~ /^NNN/)) {
			my @children = grep { $_ != $n }$p->get_children();
			$n->set_parent($p->get_parent());
			map{ $_->set_parent($n) }@children;
			$p->set_parent($n); 
		}
	}
	
	# ------------------------------
	# Rules in general
	#-------------------------------	
	
	# (i) Oblique nouns are most likely to be attached to the first non oblique noun following them.
	@desc =  $root->get_descendants( { ordered => 1 } );
	for my $i (0..($#desc-1)) {
		if ($desc[$i]->tag =~ /^NO/) {
			for my $j ($i+1..$#desc) {
				if ($desc[$j]->tag =~ /^NN/) {
					if (!$desc[$j]->is_descendant_of($desc[$i])) {
						$desc[$i]->set_parent($desc[$j]);
						last;						
					}
				}
			}
		}
	}
	
	# (ii) verbal participles are most likely to be attached to the head of the verb phrases following them.
	# The attachment need not be with the first verb phrase, it could be with any verb phrases provided they
	# are preceded by verbal participles. 
	@desc =  $root->get_descendants( { ordered => 1 } );
	for my $i (0..($#desc-1)) {
		if ($desc[$i]->tag =~ /^Vt/) {
			my $p_vt = $desc[$i]->get_parent();
			if (($p_vt != $root) && ($p_vt->tag !~ /^V/)) {
				for my $j ($i+1..$#desc) {
					if ($desc[$j]->tag =~ /^V/) {
						if (!$desc[$j]->is_descendant_of($desc[$i])) {
							$desc[$i]->set_parent($desc[$j]);
							last;						
						}
					}					
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
