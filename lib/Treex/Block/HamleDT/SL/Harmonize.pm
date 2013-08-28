package Treex::Block::HamleDT::SL::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Slovene tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone);

    
	# I have no idea why this is run in this place.
	$self->attach_final_punctuation_to_root($a_root);

    $self->change_ending_colon_to_AuxK($a_root);
    $self->change_wrong_puctuation_root($a_root);
    $self->conflate_elipsis($a_root);
	$self->change_quotation_predicate_into_obj($a_root);

}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;
        $node->set_afun($afun);

        # Unlike the CoNLL conversion of the Czech PDT 2.0, the Slovenes don't mark coordination members.
        # I suspect (but I am not sure) that they always attach coordination modifiers to a member,
        # so there are no shared modifiers and all children of Coord are members. Let's start with this hypothesis.
        # We cannot query parent's afun because it may not have been copied from conll_deprel yet.
        my $pdeprel = $node->parent()->conll_deprel();
        $pdeprel = '' if ( !defined($pdeprel) );
        if ($pdeprel =~ m/^(Coord|Apos)$/
            &&
            $afun !~ m/^(Aux[GKXY])$/
            )
        {
            $node->set_is_member(1);
        }
    }
}

#------------------------------------------------------------------------------
# Final punctuation is usually attached to the root. However, if there are
# quotation marks, these are attached to the main verb, and then the full stop
# before the final quotation mark is also attached to the main verb. Unlike
# PDT, where the quotes would be attached to the main verb and the full stop
# would be attached non-projectively to the root.
#
# However, this should be run ONLY when root has no AuxK child already.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self  = shift;
    my $root  = shift;
    my @root_children = $root->get_children();
    if ($root_children[-1]->afun() eq 'AuxK') {
        return;
    }

    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if ( $node->afun() eq 'AuxK' && $node->parent() != $root )
        {
            $node->set_parent($root);
        }
    }
}

#------------------------------------------------------------------------------
# Some sentences ends with ":", which is (logically) set as AuxG;
# however, sentences should end with AuxK.
# There is no winning solution here, since the sentences are wrong in the 
# first place; I am changing the last ":" to AuxK anyway.
#------------------------------------------------------------------------------
sub change_ending_colon_to_AuxK {
	my $self = shift;
	my $root = shift;
	my @nodes = $root->get_descendants();
	my $last_node = $nodes[-1];
	if ($last_node->form() eq ':') {
		$last_node->set_afun('AuxK');
	}
}

#------------------------------------------------------------------------------
# For some reason, punctuation right before coordinations are not dependent
# on the conjunction, but on the very root of the tree. I will make sure they
# are dependent correctly on the following word, which is the conjunction.
#------------------------------------------------------------------------------

sub change_wrong_puctuation_root {
	my $self = shift;
	my $root = shift;
	my @children = $root->get_children();
	if (scalar @children>2) {
		
								#I am not taking the last one
		for my $child (@children[0..$#children-1]) {
			if ($child->afun() =~ /^Aux[XG]$/) {
				my $conjunction = $child->get_next_node();
				if (scalar ($child->get_children())==0 and $conjunction->tag() =~ /^J/) {
					$child->set_parent($conjunction);
				}
			}
		}
	} 
}

#------------------------------------------------------------------------------
# If there are more roots, but none of them has any children that has any verb,
# I chose first root that has elipsis (ExD) and make everything children of 
# that root.
# If nothing has elipsis, I just take the first one.
# It may produce something less correct, but it will always have one root node.
#------------------------------------------------------------------------------

sub conflate_elipsis {
	my $self = shift;
	my $root = shift;
	my @children = $root->get_children();
	if (scalar @children>2) {
		my @descendants = $root->descendants;
		my @verbs = grep {$_->tag() =~ /^V/} @descendants;
		if (scalar @verbs == 0) {
			#It has no verb whatsoever => can conflate
			my $elipsis_index = undef;
			for my $index (0..$#children) {
				if ($children[$index]->afun() eq "ExD") {
					$elipsis_index = $index if (!defined $elipsis_index);
				}
			}
			
			if (!defined $elipsis_index) {
				#Oh well, taking the first one
				$elipsis_index = 0;
			}
			
			#conflating!
			CONF:
			for my $index (0..$#children) {
				if ($index != $elipsis_index) {
					if ($index == $#children) {
						#the last only if incorrect
						next CONF if ($children[$index]->tag() =~ /^Aux[XK]/);
					}
					$children[$index]->set_parent($children[$elipsis_index]);
				}
			}
		}
	}
}


#------------------------------------------------------------------------------
# Quotations should have Obj as predicate, but here, they have Adj. I have to
# switch them.
#------------------------------------------------------------------------------
sub change_quotation_predicate_into_obj {
	my $self = shift;
	my $root = shift;
	my @nodes = $root->get_descendants();
	for my $node (@nodes) {
		my @children = $node->get_children();
		my $has_quotation_dependent = 0;
		for my $child (@children) {
			if ($child->form eq q{"}) {
				if ($node->afun() eq "Adv") {
					$node->set_afun("Obj");
				}
			}
		}
	}
}



1;

=over

=item Treex::Block::HamleDT::SL::Harmonize

Converts SDT (Slovene Dependency Treebank) trees from CoNLL to the style of
the Prague Dependency Treebank. The structure of the trees should already
adhere to the PDT guidelines because SDT has been modeled after PDT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to afun. Morphological tags will be
decoded into Interset and converted to the 15-character positional tags
of PDT.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2012 Karel Bilek <kb@karelbilek.com>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
