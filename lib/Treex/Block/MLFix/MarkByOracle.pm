package Treex::Block::MLFix::MarkByOracle;

use Moose;
use Treex::Core::Common;
use utf8;
use Lingua::Interset 2.050 qw(encode);

extends 'Treex::Block::MLFix::Mark2Fix';

has ref_alignment_type => (
    is => 'rw',
    isa => 'Str',
    default => 'monolingual'
);

has ref_parent_constraint => (
    is => 'ro',
    isa => 'Bool',
    default => 1
);

sub _load_models {
    my ($self) = @_;

    # Nothing to do here

    return;
}

sub _get_predictions {
	my ($self, $instances) = @_;

    my @predictions = ();
    
    foreach my $inst (@$instances) {
        my $prediction = {};
        if (defined $inst && 
            ($self->ref_parent_constraint && $inst->{"parentold_node_lemma"} eq $inst->{"parentnew_node_lemma"}) &&
            ($inst->{"old_node_form"} ne $inst->{"new_node_form"})
        ) {
            push @predictions, 1;
            next;
        }
        push @predictions, 0;
    }
    return \@predictions;
}

sub get_instance_info {
    my ($self, $node) = @_;

    my ($node_ref) = $node->get_aligned_nodes_of_type($self->ref_alignment_type);

	my ($parent) = $node->get_eparents({
    	or_topological => 1,
    });
    my ($parent_ref) = $parent->get_aligned_nodes_of_type($self->ref_alignment_type)
		if defined $parent;
    my $info = {};	
    if (
        defined $node_ref && !$node_ref->is_root() &&
        $node->lemma eq $node_ref->lemma
    ) {
        $info = { "NULL" => "", "parentold_node_lemma" => "", "parentnew_node_lemma" => "" };
	    my $names = ["node", "parent"];
    	my $no_grandpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];

        # smtout (old) and ref (new) nodes info
    	$self->node_info_getter->add_info($info, 'old', $node, $names);
        $self->node_info_getter->add_info($info, 'new', $node_ref, $names);

    	# parents (smtout - parentold, source - parentsrc)
        $self->node_info_getter->add_info($info, 'parentold', $parent, $no_grandpa)
    		if defined $parent && !$parent->is_root();
        $self->node_info_getter->add_info($info, 'parentnew', $parent_ref, $no_grandpa)
		    if defined $parent_ref && !$parent_ref->is_root();
    }
    return $info;
}

1;

=head1 NAME 

Treex::Block::MLFix::MarkByOracle -- Marks nodes whose surface form does not match their reference node surface form.

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
