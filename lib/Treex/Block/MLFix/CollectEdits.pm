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
	return Treex::Tool::MLFix::NodeInfoGetter->new();
}

before '_do_process_document' => sub {
	my ($self) = @_;
	if ($self->print_column_names) {
		print { $self->_file_handle() } (join "\t", @{$self->fields_ar})."\n";
	}
};

sub process_anode {
    my ($self, $node) = @_;
    my ($node_ref) = $node->get_aligned_nodes_of_type($self->ref_alignment_type);
	my ($node_src) = $node->get_aligned_nodes_of_type($self->src_alignment_type);

	my ($parent_src) = $node_src->get_eparents( {or_topological => 1} )
		if defined $node_src;
	my $parent = undef;
	if (defined $parent_src) {
		my ($parent_rf) = $parent_src->get_undirected_aligned_nodes({
			rel_types => [ $self->src_alignment_type ]
		});
		($parent) = @{ $parent_rf } if defined $parent_src;
	}

    # collect only those edits that correspond to things MLfix can fix
    # (assumes we don't change lemmas and don't rehang nodes)
    # TODO is the root check a good thing? (note: beware of lemmas)
    if (
		defined $parent && !$parent->is_root() &&
		defined $parent_src && !$parent_src->is_root() &&
        defined $node_ref && !$node_ref->is_root() &&
        $node->lemma eq $node_ref->lemma 
	#	defined $parent_ref && !$parent_ref->is_root() &&
    #   $parent->lemma eq $parent_ref->lemma &&
    ) {
        my $info = { "NULL" => "" };
		# TODO: we can't access parents/children of the src, ref zones atm.
		my $names = [ "node" ];
		my $no_granpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];

        # smtout (old), ref (new) and source (src) nodes info
        $self->node_info_getter->add_info($info, 'old', $node, $names);
        $self->node_info_getter->add_info($info, 'new', $node_ref, $names);
		$self->node_info_getter->add_info($info, 'src', $node_src);
        
		# parents (smtout - parentold, source - parentsrc)
		$self->node_info_getter->add_info($info, 'parentold', $parent, $names) if defined $parent;
        $self->node_info_getter->add_info($info, 'parentsrc', $parent_src, $no_granpa) if defined $parent_src;

        my @fields = map { exists $info->{$_} ? $info->{$_} : $info->{"NULL"}  } @{$self->fields_ar};
		log_info(scalar @{$self->fields_ar});
		log_info($self->fields_ar->[0]);
        print { $self->_file_handle() } (join "\t", @fields)."\n";
    }
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

