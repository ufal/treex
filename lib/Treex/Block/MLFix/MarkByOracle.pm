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
        if (defined $inst->{"wrong_form_3"} && $inst->{"wrong_form_3"} == 1
#            ($self->ref_parent_constraint && $inst->{"parentold_node_lemma"} eq $inst->{"parentnew_node_lemma"}) && 
#            ($self->ref_parent_constraint && lc($inst->{"parentold_node_form"}) eq lc($inst->{"parentnew_node_form"})) &&
#             ($self->ref_parent_constraint && (lc($inst->{"parentold_node_form"}) eq lc($inst->{"parentnew_node_form"})) || ($inst->{"parentold_node_lemma"} eq $inst->{"parentnew_node_lemma"} && lc($inst->{"parentold_parent_form"}) eq lc($inst->{"parentnew_parent_form"}))) &&
#            (lc($inst->{"old_node_form"}) ne lc($inst->{"new_node_form"}))
        ) {
            push @predictions, { "Oracle" => { 1 => 1, 0 => 0 } };
            next;
        }
        push @predictions, { "Oracle" => { 0 => 1, 1 => 0 } };
    }
    return \@predictions;
}

sub get_instance_info {
    my ($self, $node) = @_;

    my ($node_ref) = $node->get_aligned_nodes_of_type($self->ref_alignment_type);

	my ($parent) = $node->get_eparents({
    	or_topological => 1,
        ignore_incorrect_tree_structure => 1
    });
    
    my $parent_ref = undef;
    if (defined $node_ref) {
        ($parent_ref) = $node_ref->get_eparents( {or_topological => 1, ignore_incorrect_tree_structure => 1} );
    }
    if (!defined $parent_ref || $parent_ref->is_root()) {
        ($parent_ref) = $parent->get_aligned_nodes_of_type($self->ref_alignment_type) if defined $parent;
    }

    my $info = {};	
    if ($self->can_extract_instance($node, $node_ref, $parent, $parent_ref)) {
        $info = { "NULL" => "", "parentold_node_form" => "", "parentnew_node_form" => "" };
	    my $flags_node_only = ["node"];
    	my $flags_no_grandpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];

        # smtout (old) and ref (new) nodes info
    	$self->node_info_getter->add_info($info, 'old', $node, $flags_node_only);
        $self->node_info_getter->add_info($info, 'new', $node_ref, $flags_node_only);

    	# parents (smtout - parentold, source - parentsrc)
        $self->node_info_getter->add_info($info, 'parentold', $parent, $flags_no_grandpa);
        $self->node_info_getter->add_info($info, 'parentnew', $parent_ref, $flags_no_grandpa);

        $info->{"wrong_form_1"} = 0;
        $info->{"wrong_form_2"} = 0;
        $info->{"wrong_form_3"} = 0;
        if(lc($node->form) ne lc($node_ref->form)) {
            $info->{"wrong_form_1"} = 1;
            $info->{"wrong_form_2"} = 1 if (defined $parent_ref && lc($parent->form) eq lc($parent_ref->form));
            $info->{"wrong_form_3"} = $info->{"wrong_form_2"};
            $info->{"wrong_form_3"} = 1 if $self->was_modified($parent, "wrong_form_3");
        }
    }
    return $info;
}

# check, if it is reasonable to collect instance info
sub can_extract_instance {
    my ($self, $node, $node_ref, $parent, $parent_ref) = @_;

    return 0 if (!defined $node_ref || $node_ref->is_root);
    return 0 if ($node->lemma ne $node_ref->lemma);
    return 0 if (!defined $parent || $parent->is_root());
    return 0 if (!defined $parent_ref || $parent_ref->is_root());

    return 1;
}

sub was_modified {
    my ($self, $node, $mod_type) = @_;
    return 0 if $mod_type !~ /wrong_form_/;

    if (defined $node->wild->{$mod_type}) {
        return 1 if $node->wild->{$mod_type} == 1;
    }
    else {
        my $info = $self->get_instance_info($node);
        $info->{$mod_type} = 0 if !defined $info->{$mod_type};
        $node->wild->{$mod_type} = $info->{$mod_type};
        return 1 if $info->{$mod_type} == 1;
    }
    return 0;
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
