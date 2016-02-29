package Treex::Block::MLFix::MLFix;

use Moose;
use Treex::Core::Common;
use utf8;
use List::Util "reduce";

#use Treex::Tool::MLFix::Model;
use Treex::Tool::MLFix::FixLogger;
use Treex::Tool::MLFix::NodeInfoGetter;
extends 'Treex::Core::Block';

#with 'Treex::Tool::MLFix::FixLogger';

# TODO: smt parent aquisition through both alignment or dependency tree depending on the a-tree presence

# TODO: throw away unnecessary stuff

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

has smt_parsed => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
    documentation => 'Did we perform the parsing of the smt output'
);

has config_file => (
	is => 'rw',
	isa => 'Str',
	required => 1,
	documentation => 'Contains: list of models, list of feature names, attributes we want to predict.'
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

has formGenerator => (
	is	 => 'rw',
	builder => '_build_form_generator'
);

has form_recombination => (
	is => 'rw',
	isa => 'Bool',
	default => '0'
);

has fixLogger => (
	is => 'rw',
	builder => '_build_fix_logger'
);

has log_to_console => (
	is => 'rw',
	isa => 'Bool',
	default => 1
);

has try_switch_number => (
	is => 'rw',
	isa => 'Bool',
	default => '0'
);

has magic => ( is => 'rw', isa => 'Str', default => '' );

has node_info_getter => (
	is => 'rw',
	builder => '_build_node_info_getter'
);

has iset_driver => (
     is            => 'ro',
     isa           => 'Str',
     required      => 1,
     documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                      'The default value must be set in blocks derived from this block. '.
                      'Lowercase, language code :: treebank code, e.g. "en::conll".'
);

sub _build_form_generator {
    my ($self) = @_;

    log_fatal "Abstract method _build_form_generator must be overridden!";

    return;
}

sub _build_node_info_getter {
	return Treex::Tool::MLFix::NodeInfoGetter->new();
}

sub _load_models {
    my ($self) = @_;

    log_fatal "Abstract method _load_models must be overridden!";

    return;
}

sub _build_fix_logger {
	my ($self) = @_;
	return Treex::Tool::MLFix::FixLogger->new({
		language => $self->language,
		log_to_console => $self->log_to_console
	});
}

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);

    return;
}

# TODO: can we also consider t-trees?
sub process_atree {
    my ($self, $root) = @_;

	# TODO: another processing direction?
    $self->process_node_recursively_topdown($root);

    return;
}

sub process_node_recursively_topdown {
    my ($self, $node) = @_;

    $self->process_anode($node);
    my @children = $node->get_children();
    foreach my $child (@children) {
        $self->process_node_recursively_topdown($child);
    }

    return;
}

#override 'process_anode' => {
sub process_anode {
    my ($self, $node) = @_;

    if ( $node->is_root() ) {
        return;
    }
    
	# here stuff happens
    # TODO: look into this and throw it away if not necessary
	my $instance_info = $self->get_instance_info($node);
    if ( $self->magic ne '' ) {
        my $continue = 0;
	       
		if ( $self->magic =~ '_noun_' &&
			$instance_info->{old_node_pos} eq 'noun' ) {
			$continue = 1;
		}

		if ( $self->magic =~ '_adj_' &&
			$instance_info->{old_node_pos} eq 'adj' ) {
			$continue = 1;
		}

		if ( $self->magic =~ '_verb_' &&
			$instance_info->{old_node_pos} eq 'verb' ) {
			$continue = 1;
		(
 
        if ( $self->magic =~ '_subjchild_' &&
            $instance_info->{old_precchild_afun} eq 'Sb' ) {
            $continue = 1;
        }
        
        if ( $self->magic =~ '_adj_' &&
            $instance_info->{old_node_pos} eq 'A' ) {
            $continue = 1;
        }

        if ( $self->magic =~ '_prep_' &&
            $instance_info->{new_parent_pos} eq 'R' ) {
            $continue = 1;
        }

        if ( $self->magic =~ '_verbnoun_' &&
            $instance_info->{new_parent_pos} eq 'V' &&
            $instance_info->{old_node_pos} eq 'N'
        ) {
            $continue = 1;
        }

        if ( !$continue ) {
            return;
        }
    }
	
	# Apply rule - generalize predict_new_tag (predict_new_tag would became a rule)
    # How will the "predict" features look?

    my $new_tag = $self->predict_new_tag($node, $instance_info);
    if ( defined $new_tag && $new_tag ne $node->tag ) {
		$self->fixLogger->logfix1($node);
        $self->regenerate_node($node, $new_tag);
        $self->fixLogger->logfix2($node);
    }

    return;	
}

sub predict_new_tag {
    my ($self, $node, $instance_info) = @_;

    # get predictions from models
    my $model_predictions = {};
    my @model_names = keys %{$self->_models};
    foreach my $model_name (@model_names) {
        my $model = $self->_models->{$model_name};
        $model_predictions->{$model_name} =
            $model->get_predictions($instance_info);
    }

    # process predictions to get tag suggestions
    my $new_tags = $self->_predict_new_tags($model_predictions);

    my $new_tag;
    if ( $self->form_recombination) {
        # recombinantion according to form
        my %forms = ();
        foreach my $tag (keys %$new_tags) {
            my $form = $self->formGenerator->get_form( $node->lemma, $tag );
            if (defined $form) {
                $forms{$form}->{score} += $new_tags->{$tag};
                $forms{$form}->{tags}->{$tag} = $new_tags->{$tag};
            }
        }
        my $message = 'MLFix (' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $new_tags->{$_}) }
                sort {$new_tags->{$b} <=> $new_tags->{$a}}
                    keys %$new_tags) ) . 
        ' ' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $forms{$_}->{score}) }
                sort {$forms{$b} <=> $forms{$a}}
                    keys %forms) ) .
        ')';
        $self->fixLogger->logfix1($node, $message);

        # find new form and tag
        my $new_form = reduce {
            $forms{$a}->{score} > $forms{$b}->{score} ? $a : $b
        } keys %forms;
        if (defined $new_form) {
            my $tags = $forms{$new_form}->{tags};
            $new_tag = reduce { $tags->{$a} > $tags->{$b} ? $a : $b } keys %$tags;
        }
    } else {
        my $message = 'MLFix (' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $new_tags->{$_}) }
                sort {$new_tags->{$b} <=> $new_tags->{$a}}
                    keys %$new_tags) ) . 
        ')';
        $self->fixLogger->logfix1($node, $message);

        $new_tag = reduce { $new_tags->{$a} > $new_tags->{$b} ? $a : $b }
            keys %$new_tags;        
    }

    if ( defined $new_tag && $new_tag ne $node->tag ) {
        return $new_tag;
    } else {
        return;
    }
}

sub _predict_new_tags {
    my ($self, $node, $model_predictions) = @_;

    log_fatal "Abstract method _predict_new_tag must be overridden!";

    return;
}

sub get_instance_info {
    my ($self, $node) = @_;

	my ($node_src)  = $node->get_aligned_nodes_of_type($self->src_alignment_type);
    my ($parent, $parent_src) = undef, undef;

    if ($self->smt_parsed) {
        ($parent) = $node->get_eparents({
            or_topological => 1,
            ignore_incorrect_tree_structure => 1
        });
        ($parent_src) = $parent->get_aligned_nodes_of_type($self->src_alignment_type);
    }
    else {
        ($parent_src) = $node_src->get_eparents( {or_topological => 1} )
            if defined $node_src;
        if (defined $parent_src) {
            my ($parent_rf) = $parent_src->get_undirected_aligned_nodes({
                rel_types => [ $self->src_alignment_type ]
            });
            ($parent) = @{ $parent_rf };
        }
    }

	# TODO: see CollectEdits
    my $info = {};
	my $names = ["node"];

    # smtout (old) and source (src) nodes info
	$self->node_info_getter->add_info($info, 'old', $node);
    $self->node_info_getter->add_info($info, 'src',   $node_src);

	# parents (smtout - parentold, source - parentsrc)
    $self->node_info_getter->add_info($info, 'parentold', $parent, $names)
		if defined $parent;
    $self->node_info_getter->add_info($info, 'parentsrc', $parent_src)
		if defined $parent_src;

    return $info;
}

# changes the tag in the node and regenerates the form correspondingly
# only a wrapper
sub regenerate_node {
    my ( $self, $node, $new_tag ) = @_;

    if (defined $new_tag) {
        $node->set_tag($new_tag);
    }

    return $self->formGenerator->regenerate_node( $node, $self->try_switch_number );
}


1;

=head1 NAME 

Treex::Block::MLFix::MLFix -- fixes errors using a machine learned correction model

=head1 DESCRIPTION

We try to predict new POS, not directly, but via prediction of the Interset
categories and their transformation to the target language tagset.

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

