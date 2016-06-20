package Treex::Block::MLFix::Mark2Fix;

use Moose;
use Treex::Core::Common;
use utf8;
use List::Util "reduce";
use YAML::Tiny;

use Treex::Tool::MLFix::FixLogger;
use Treex::Tool::MLFix::NodeInfoGetter;
extends 'Treex::Core::Block';

has '+language'	=> ( required => 1 );
has '+selector' => ( required => 1 );

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

has config_file => (
	is => 'rw',
	isa => 'Str',
	required => 1,
	documentation => 'Contains: list of models, list of feature names.'
);

has config => (
	is => 'rw'
);

has _models => (
	is => 'rw',
	isa => 'HashRef',
	lazy => '1',
	builder => '_load_models'
);

has src_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'intersection'
);
has orig_alignment_type => (
	is => 'rw',
	isa => 'Str',
	default => 'copy'
);

has node_info_getter => (
	is => 'rw',
	builder => '_build_node_info_getter'
);

sub _build_node_info_getter {
	return Treex::Tool::MLFix::NodeInfoGetter->new();
}

sub _load_models {
    my ($self) = @_;

    log_fatal "Abstract method _load_models must be overridden!";

    return;
}

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);

    return;
}

sub process_atree {
    my ($self, $root) = @_;

    #$self->process_node_recursively_topdown($root);
	$self->process_whole_sentence($root);

    return;
}

sub process_whole_sentence {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants({ ordered => 1 });
	my @instances = map { $self->get_instance_info($_) } @nodes;

	my $predictions = $self->predict_if_mark(\@nodes, \@instances);	
	if (scalar @nodes != scalar @$predictions) {
		log_fatal("Incorect number of predictions. Expected: " . scalar @nodes . "Got: " . scalar @$predictions);
	}

	my $iterator = List::MoreUtils::each_arrayref(\@nodes, $predictions);
	while (my ($node, $pred) = $iterator->() ) {
        log_debug($node->form . ": " . $pred);
        $node->wild->{"marked2fix"} = $pred;
	}
	return;
}

sub predict_if_mark {
    my ($self, $nodes_rf, $instances) = @_;

    return $self->_get_predictions($instances);

}

# This method can be overwritten in the descendants,
# since we can generate the predictions array in a different way.
# e.g.: when predicting the whole array of instances is faster than taking only one instance at a time
sub _get_predictions {
	my ($self, $instances) = @_;

	my @model_predictions_array = map { {} } @$instances;

	foreach my $instance_info ($instances) {
		my @model_names = keys %{$self->_models};
		my $model_predictions = {};
    	foreach my $model_name (@model_names) {
        	my $model = $self->_models->{$model_name};
        	$model_predictions->{$model_name} =
            	$model->get_predictions($instance_info);
		}
		push @model_predictions_array, $model_predictions;
    }

	return \@model_predictions_array;
}

sub get_instance_info {
    my ($self, $node) = @_;

	my ($node_src)  = $node->get_aligned_nodes_of_type($self->src_alignment_type);

	my ($parent) = $node->get_eparents({
    	or_topological => 1,
    	ignore_incorrect_tree_structure => 1
    });
    my ($parent_src) = $node_src->get_eparents( {or_topological => 1} )
		if defined $node_src;
	
    my $info = {};
	my $names = ["node"];
	my $no_grandpa = [ "node", "parent", "precchild", "follchild", "precsibling", "follsibling" ];

    # smtout (old) and source (src) nodes info
	$self->node_info_getter->add_info($info, 'old', $node);
    $self->node_info_getter->add_info($info, 'src',   $node_src);
#		if defined $node_src;

	# parents (smtout - parentold, source - parentsrc)
    $self->node_info_getter->add_info($info, 'parentold', $parent, $no_grandpa)
		if defined $parent && !$parent->is_root();
    $self->node_info_getter->add_info($info, 'parentsrc', $parent_src, $no_grandpa)
		if defined $parent_src && !$parent_src->is_root();

    return $info;
}

1;

=head1 NAME 

Treex::Block::MLFix::Mark2Fix -- Marks nodes, which should be fixed by the MLFix Block

=head1 DESCRIPTION

We set the $node->wild{"toFix"} for the nodes that are classified as morphologically
incorrect. The following MLFix block should apply fix logic on these nodes.

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
