package Treex::Block::MLFix::CollectEdits;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

use Treex::Tool::MLFix::NodeInfoGetter;

has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has '+extension' => (default => '.tsv');
has '+stem_suffix' => (default => '_edits');
has '+compress' => (default => '1');

has src_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'intersection'
);
has ref_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'monolingual'
);

has config_file => (
	is => 'rw',
	isa => 'Str',
	default => ''
);
has print_column_names => (
	is => 'rw',
	isa => 'Bool',
	default => '0'
);

has fields => (	
	is => 'rw',
	isa => 'Str',
	default => 'old_node_lemma src_node_form parentsrc_node_afun src_node_tag parentsrc_node_tag'
);

has fields_ar => (
	is => 'rw',
	lazy => 1,
	builder => '_build_fields_ar'
);

has node_info_getter => (
	is => 'rw',
	builder => '_build_node_info_getter'
);

has no_source => (
    is => 'ro',
    isa => 'Bool',
    default => '0',
    documentation => 'No source sentences providesd'
);

sub _build_fields_ar {
    my ($self) = @_;

    if ( $self->config_file ne '' ) {
        use YAML::Tiny;
        my $config = YAML::Tiny->new;
        $config = YAML::Tiny->read( $self->config_file );
        return $config->[0]->{fields};
    } else {
        my @fields = split / /, $self->fields;
        return \@fields;
    }
}

sub _build_node_info_getter {
	return Treex::Tool::MLFix::NodeInfoGetter->new( agr2wild => 1 );
}

before '_do_process_document' => sub {
	my ($self) = @_;
	if ($self->print_column_names) {
		print { $self->_file_handle() } (join "\t", @{$self->fields_ar})."\n";
	}
};

sub process_anode {
    my ($self, $node) = @_;

    my $info = {};
    $info = $self->get_instance_info($node);

    if (%$info) {
        my @fields = map { defined $info->{$_} ? $info->{$_} : $info->{"NULL"}  } @{$self->fields_ar};
        print { $self->_file_handle() } (join "\t", @fields)."\n";
    }
}

sub get_instance_info {
    my ($self, $node) = @_;
    my ($node_ref) = $node->get_aligned_nodes_of_type($self->ref_alignment_type);
	my ($node_src) = $node->get_aligned_nodes_of_type($self->src_alignment_type);

	my ($parent) = $node->get_eparents( {or_topological => 1, ignore_incorrect_tree_structure => 1} );
	my ($parent_src) = $node_src->get_eparents( {or_topological => 1, ignore_incorrect_tree_structure => 1} )
		if defined $node_src;

    my $parent_ref = undef;
    if (defined $node_ref) {
        ($parent_ref) = $node_ref->get_eparents( {or_topological => 1, ignore_incorrect_tree_structure => 1} );
    }
    if (!defined $parent_ref || $parent_ref->is_root()) {
        ($parent_ref) = $parent->get_aligned_nodes_of_type($self->ref_alignment_type) if defined $parent;
    }

    my $info = {};
    # collect only those edits that correspond to things MLfix can fix
    # (assumes we don't change lemmas and don't rehang nodes)
    # TODO is the root check a good thing? (note: beware of lemmas)
    if ($self->can_extract_instance($node, $node_src, $node_ref, $parent, $parent_src, $parent_ref)) {
        $info = { "NULL" => "" };
		my $flags_node_only = [ "node" ];
		my $flags_no_grandpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];
        my $flags_no_parent = [ "node", "precchild", "follchild", "precsibling", "follsibling" ];

        # smtout (old), ref (new) and source (src) nodes info
        $self->node_info_getter->add_info($info, 'old', $node, $flags_no_parent);
        $self->node_info_getter->add_info($info, 'new', $node_ref, $flags_node_only);
        
		# parents (smtout - parentold, source - parentsrc)
		$self->node_info_getter->add_info($info, 'parentold', $parent, $flags_no_grandpa);
        $self->node_info_getter->add_info($info, 'parentnew', $parent_ref, $flags_node_only);

        if (!$self->no_source) {
            $self->node_info_getter->add_info($info, 'src', $node_src, $flags_no_parent);
            $self->node_info_getter->add_info($info, 'parentsrc', $parent_src, $flags_no_grandpa);
        }

        $info->{"wrong_form_1"} = 0;
        $info->{"wrong_form_2"} = 0;
        $info->{"wrong_form_3"} = 0;
        if(lc($node->form) ne lc($node_ref->form)) {
            $info->{"wrong_form_1"} = 1;
            $info->{"wrong_form_2"} = 1 if (defined $parent_ref && lc($parent->form) eq lc($parent_ref->form));
            $info->{"wrong_form_3"} = $info->{"wrong_form_2"};
            $info->{"wrong_form_3"} = 1 if $self->was_modified($parent, "wrong_form_3");
        }

        $info->{"old_node_id"} = $node->id;
    }
    return $info;
}

# Check if we can extract desirable features from this instance
sub can_extract_instance {
    my ($self, $node, $node_src, $node_ref, $parent, $parent_src, $parent_ref) = @_;
   
    return 0 if (!defined $parent || $parent->is_root());
    return 0 if (!defined $node_ref || $node_ref->is_root);
    return 0 if ($node->lemma ne $node_ref->lemma);
    return 0 if (!defined $parent_ref || $parent_ref->is_root());

    if (!$self->no_source) {
        return 0 if (!defined$parent_src || $parent_src->is_root());
    }

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

Treex::Block::MLFix::CollectEdits

=head1 DESCRIPTION

A MLFix block.

Collects and prints a list of performed edits, comparing the original machine
translation with the reference translation (ideally human post-editation).
To be used to get data to train MLFix.

The fields to be captured can be configured either with a comma delimited list
in C<fields>, or by a config file in C<config_file> (which has priority).
See C<sample_config.yaml> in the C<Treex::Block::MLFix> directory for a sample.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

