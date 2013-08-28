package Treex::Block::HamleDT::TA::FixProjectedEdges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'tb_style' => (isa => 'Str', is => 'ro', default => 'tamiltb1.0');

has 'source_language' => (isa => 'Str', is => 'ro', default => 'en');
has 'source_selector' => (isa => 'Str', is => 'ro', default => '');
has 'source_tb_style' => (isa => 'Str', is => 'ro', default => 'penn');
has 'alignment_type'  => (isa => 'Str', is => 'ro', default => 'alignment');
 

sub process_atree {
	my ($self, $root) = @_;	
	$self->fix_projected_edges($root);
}

sub fix_projected_edges {
	my ($self, $root) = @_;
	
	if (($self->source_tb_style eq 'penn') && ($self->tb_style eq 'tamiltb1.0')) {
		
		# source descendants
		my $source_root = $root->get_bundle->get_zone( $self->source_language, $self->source_selector )->get_atree();
		my @source_desc = $source_root->get_descendants( { ordered => 1 } );

		# (i) Sometimes a verb in English is expressed as a 'nominal verb' combination
		# in Tamil. In Tamil annotation, 'verb' is the head and the 'nominal' is 
		# the child. 
		my @desc =  $root->get_descendants( { ordered => 1 } );
		foreach my $n (@desc) {
			my $p = $n->get_parent();
			if (($n->tag =~ /^V[rRzZ]/) && ($p != $root) && ($p->tag =~ /^NNN/)) {
				my @children = grep { $_ != $n }$p->get_children();
				#if (!$p->get_parent()->is_descendant_of($n)) {
					$n->set_parent($p->get_parent());
					$p->set_parent($n);
					map { $_->set_parent($n)}@children;	
				#}
			}
		}
	
		# (ii) Fix coordination to target style
		foreach my $sc (@source_desc) {
			# locate coordinations in the source and get the corresponding coordination head in the target
			if (($sc->form =~ /^(,|and)$/) && ($sc->afun eq 'Coord')) {
				my @aligned_nodes = $sc->get_aligned_nodes_of_type('^' . $self->alignment_type . '$', $self->language, $self->selector);
				if (scalar(@aligned_nodes) == 1) {
					if ( ($aligned_nodes[0]->form =~ /^(,|மற்றும்)$/) && (!$aligned_nodes[0]->is_leaf())){
						my @members = $aligned_nodes[0]->get_children({ordered=>1});
						my $par_of_coord = $aligned_nodes[0]->get_parent();
						# choose Tamil coordination head
						my $new_coord_head = $members[$#members]; 
						$new_coord_head->set_parent($par_of_coord);
						# attach other members
						for my $i (0..($#members-1)) {
							$members[$i]->set_parent($new_coord_head);
						}
						$aligned_nodes[0]->set_parent($new_coord_head);
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

Treex::Block::HamleDT::TA::FixProjectedEdges - Implements language specific rules to fix projection errors

=head1 SYNOPSIS

HamleDT::TA::FixProjectedEdges projected_from='en'

=head1 DESCRIPTION

This block fixes some of the systematic incorrect edge attachments (mainly due to annotation style) in the projection.
 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
