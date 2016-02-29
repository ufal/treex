package Treex::Block::MLFix::Fix;
use Moose;
use Treex::Core::Common;
use utf8;
use Carp;
extends 'Treex::Core::Block';

with 'Treex::Tool::MLFix::FixLogger';
with 'Treex::Tool::MLFix::FormGenerator';
# logfix1(+$child, +$msg)
# logfix2(?$child)

has '+language'       => ( required => 1 );
has source_language => (
	is => 'rw',
	isa => 'Str',
	default => 'en'
);
has source_selector => (
	is => 'rw',
	isa => 'Str',
	default => ''
);
has smt_parsed => (
	is => 'ro',
	isa => 'Bool',
	default => 0,
	documentation => 'Did we perform the parsing of the smt output'
);

has 'magic' => (
	is => 'rw',
	isa => 'Str',
	default => ''
);

# alignment has to go from nodes being fixed to other nodes
has src_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'intersect'
);
has orig_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'copy'
);

has iset_driver => (
     is            => 'ro',
     isa           => 'Str',
     required      => 1,
     documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                      'The default value must be set in blocks derived from this block. '.
                      'Lowercase, language code :: treebank code, e.g. "en::conll".'
);

# this sub is to be to be redefined in child module
sub fix {
	my ($self, $node, $parent, $node_src, $parent_src) = @_;
	
	log_fatal("Abstract method fix must be overriden");

	return;
}

}

sub process_anode {
    my ( $self, $node ) = @_;
    return if $node->isa('Treex::Core::Node::Deleted');

    my ($node_src)  = $child->get_aligned_nodes_of_type($self->src_alignment_type);

	my ($parent, $parent_src) = undef, undef;

	if ($self->smt_parsed) {
		($parent) = $child->get_eparents({
        	or_topological => 1,
        	ignore_incorrect_tree_structure => 1
	    });
    	# return if $parent->is_root;
    	($parent_src) = $parent->get_aligned_nodes_of_type($self->src_alignment_type);
	}
	else {
		($parent_src) = $node_src->get_eparents( {or_topological => 1} )
			if defined $node_src;
		if (defined $parent_src) {
			my ($parent_rf) = $parent_src->get_undirected_aligned_nodes({
				rel_types => [ $self->src_alignment_type ]
			});
			$parent = @$parent_rf->[0];
		}
	}

    return $self->fix( $node, $parent, $node_src, $parent_src );
}

sub get_aligned {
    my ( $self, $node ) = @_;
    return $node->get_aligned_nodes_of_type($self->src_alignment_type);
}

# tries to guess whether the given node is a name
sub isName {
    my ( $self, $node ) = @_;

    # TODO: now very unefficient implementation,
    # should be computed and hashed at the beginning
    # and then use something like return $is_named_entity{$node->id}

    if ( $node->lemma ne lc($node->lemma) ) {
        return 1;
    }

    # the form is not in lowercase
    if ( $node->form ne lc($node->form) ) {
        # first word node of the sentence
        my ($first) = grep { $_->form =~ /\w/ } $node->get_root->get_descendants({ordered =>1});
        # node is not first node of the sentence
        return $first->id ne $node->id;
    }

    if (!$node->get_bundle->has_tree(
            $self->language, 'n', '' )
    ) {
        log_warn "n tree is missing!";
        return 0;
    }

    my $n_root = $node->get_bundle->get_tree( $self->language, 'n', '' );

    # all n nodes
    my @n_nodes = $n_root->get_descendants();
    foreach my $n_node (@n_nodes) {

        # all a nodes that are named entities
        my @a_nodes = $n_node->get_anodes();
        foreach my $a_node (@a_nodes) {
            if ( $node->id eq $a_node->id ) {

                # this node is a named entity
                return 1;
            }
        }
    }
    return 0;
}

sub shift_subtree_before_node {
    my ($self, $subtree_root, $node) = @_;
    
    # try to normalize spaces
    # TODO: I am sure I am reinventing America here -> find a block for that!
    
    # important nodes
    my $node_preceding = $node->get_prev_node();
    my $subtree_rightmost = $subtree_root->get_descendants(
        {add_self => 1, last_only => 1});
    my $subtree_preceding = $subtree_root->get_descendants(
        {add_self => 1, first_only => 1})->get_prev_node();
    # remember the no_space_after ("nsa") values
    my $node_preceding_nsa =
        defined $node_preceding ? $node_preceding->no_space_after : 0;
    my $subtree_preceding_nsa =
        defined $subtree_preceding ? $subtree_preceding->no_space_after : 0;
    my $subtree_rightmost_nsa = $subtree_rightmost->no_space_after;
    # set the nsa values
    if (defined $node_preceding) {
        $node_preceding->set_no_space_after($subtree_preceding_nsa);
    }
    if (defined $subtree_preceding) {
        $subtree_preceding->set_no_space_after($subtree_rightmost_nsa);
    }
    $subtree_rightmost->set_no_space_after($node_preceding_nsa);
        
    # do the shift
    $subtree_root->shift_before_node($node);
    
    # ucfirst if beginning of sentence
    my $first = $subtree_root->get_descendants({add_self=>1,first_only=>1});
    if ($first->ord eq '1') {
        $first->set_form(ucfirst($first->form));
    }

    return;
}

sub shift_subtree_after_node {
    my ($self, $subtree_root, $node) = @_;
    
    # lc if beginning of sentence
    my $first = $subtree_root->get_descendants({add_self=>1,first_only=>1});
    if ( $first->ord eq '1' && $first->lemma eq lc($first->lemma) ) {
        $first->set_form(lc($first->form));
    }

    # try to normalize spaces
    # TODO: I am sure I am reinventing America here -> find a block for that!

    # important nodes
    my $subtree_rightmost = $subtree_root->get_descendants(
        {add_self => 1, last_only => 1});
    my $subtree_preceding = $subtree_root->get_descendants(
        {add_self => 1, first_only => 1})->get_prev_node();
    # remember the no_space_after ("nsa") values
    my $node_nsa = $node->no_space_after;
    my $subtree_rightmost_nsa = $subtree_rightmost->no_space_after;
    my $subtree_preceding_nsa = defined $subtree_preceding ? $subtree_preceding->no_space_after : 0;
    # set the nsa values
    $node->set_no_space_after($subtree_preceding_nsa);
    $subtree_rightmost->set_no_space_after($node_nsa);
    if (defined $subtree_preceding) {
        $subtree_preceding->set_no_space_after($subtree_rightmost_nsa);
    }
        
    # do the shift
    $subtree_root->shift_after_node($node);
    
    return;
}

# removes a node, moving its children under its parent
sub remove_node {
    my ( $self, $node ) = @_;

    #move children under parent
    my $parent = $node->get_parent;
    foreach my $child ( $node->get_children ) {
        $child->set_parent($parent);
    }

    #remove
    $node->remove();

    return;
}

sub add_parent {
    my ( $self, $parent_info, $node ) = @_;

    if (!defined $node) {
        log_warn("Cannot add parent to undefined node!");
        return;
    }
    
    my $old_parent = $node->get_parent();
    my $new_parent = $old_parent->create_child($parent_info);
    $new_parent->set_parent($old_parent);
    $new_parent->shift_before_subtree(
        $node, { without_children => 1 }
    );

    return $new_parent;
}

1;

=pod

=encoding utf-8

=head1 NAME 

Treex::Block::MLFix::Fix

=head1 DESCRIPTION

!!! Obsolete, should be only used as a reference !!!

Base class for grammatical errors fixing (common ancestor of all
C<MLFix::*::Fix> fixing modules).

A loop goes through all nodes in the analytical tree, gets their effective
parent and their aligned nodes, and passes this data to the C<fix()>
sub. In this module, the C<fix()> has an empty implementation - it is to be
redefined in children modules.

The C<fix()> sub can make use of subs defined in this module.

To log changes that were made into the tree that was changed (into the
sentence in a zone cs_FIXLOG),
call C<logfix1()> before effecting the change
and C<logfix2()> after effecting the change.

=head2 METHODS

=item * C<fix>

Method that must be redefined in the child modules. 

Implementation example:

    my ( $self, $child, $parent, $al_child, $al_parent ) = @_;

    if (!$parent->is_root) {    #if something holds

        #do something here

        $self->logfix1($child, "some change was made");
        $self->regenerate_node($parent, $child->tag);
        $self->logfix2($child);
    }
    
    return;

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
