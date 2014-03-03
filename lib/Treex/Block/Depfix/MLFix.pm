package Treex::Block::Depfix::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;
use Treex::Tool::Depfix::Model;
use Treex::Tool::Depfix::CS::FixLogger;
use List::Util "reduce";

use Treex::Tool::Depfix::Base;
use Treex::Tool::Depfix::MaxEntModel;
use Treex::Tool::Depfix::NaiveBayesModel;
use Treex::Tool::Depfix::DecisionTreesModel;
use Treex::Tool::Depfix::OldDecisionTreesModel;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'align_forward' );
has orig_alignment_type => ( is => 'rw', isa => 'Str', default => 'copy' );
has formGenerator => ( is => 'rw' );
# has _formGenerator => ( is => 'rw', isa => 'Treex::Tool::Depfix::FormGenerator' );
has _models => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
# has _models => ( is => 'rw', isa => 'HashRef[Treex::Tool::Depfix::Model]', default => sub { {} } );
has form_recombination => ( is => 'rw', isa => 'Bool', default => 1 );
# which node to fix; implies top-down or bottom-up walk through the tree
# has fix_child => ( is => 'rw', isa => 'Bool', default => 1 );

has fixLogger => ( is => 'rw' );
has log_to_console => ( is => 'rw', isa => 'Bool', default => 1 );

has 'dont_try_switch_number' => ( is => 'rw', isa => 'Bool', default => '0' );

# fix only what has not been fixed yet
# (assumption: the first performed correction is the best correction)
#has fix_only_nonfixed => ( is => 'rw', isa => 'Bool', default => 0 );

has magic => ( is => 'rw', isa => 'Str', default => '' );

use Treex::Tool::Depfix::NodeInfoGetter;

has node_info_getter => ( is => 'rw', builder => '_build_node_info_getter' );
has src_node_info_getter => ( is => 'rw', builder => '_build_src_node_info_getter' );

sub _build_node_info_getter {
    return Treex::Tool::Depfix::NodeInfoGetter->new();
}
sub _build_src_node_info_getter {
    return Treex::Tool::Depfix::NodeInfoGetter->new();
}

sub process_start {
    my ($self) = @_;

    $self->set_formGenerator($self->_build_form_generator());
    $self->_load_models();
    $self->set_fixLogger(Treex::Tool::Depfix::CS::FixLogger->new({
        language => $self->language,
        log_to_console => $self->log_to_console
    }));

    super();

    return;
}

sub _build_form_generator {
    my ($self) = @_;

    log_fatal "Abstract method _build_form_generator must be overridden!";

    return;
}

sub _load_models {
    my ($self) = @_;

    log_fatal "Abstract method _load_models must be overridden!";

    return;
}

sub process_tree {
    my ($self, $root) = @_;

    #if ( $self->fix_child ) {
        $self->process_node_recursively_topdown($root);
    #} else {
        #$self->process_node_recursively_bottomup($root); 
    #}

    return;
}

sub process_node_recursively_topdown {
    my ($self, $node) = @_;

    $self->process_anode($node);
    my @children = $node->get_children();
    foreach my $child (@children) {
        $self->process_node_recursively($child);
    }

    return;
}

#sub process_node_recursively_bottomup {
#    my ($self, $node) = @_;
#
#    my @children = $node->get_children();
#    foreach my $child (@children) {
#        $self->process_node_recursively($child);
#    }
#    $self->process_anode($node);
#
#    return;
#}

sub process_anode {
    my ($self, $node) = @_;

    if ( $node->is_root() ) {
        return;
    }
    
    my ($parent) = $node->get_eparents( {or_topological => 1} );
    if ( $parent->is_root() ) {
        return;
    }

#    if ( $self->fix_only_nonfixed ) {
#        my ($node_orig) =
#            $node->get_aligned_nodes_of_type($self->orig_alignment_type);
#        if ( (!defined $node_orig) || ($node_orig->form ne $node->form) ) {
#            return;
#        }
#    }
#
#
#    if ( $self->magic eq 'noverbparent' ) {
#        if ( $parent->tag =~ /^V/ ) {
#            return;
#        }
#    }

    # here stuff happens
    my $instance_info = $self->get_instance_info($node);
    if ( $self->magic ne '' ) {
        my $continue = 0;
        
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

        if ( !$continue ) {
            return;
        }
    }
    my $new_tag = $self->predict_new_tag($node, $instance_info);
    if ( defined $new_tag ) {
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
    my $new_tags = $self->_predict_new_tags($node, $model_predictions);

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

    my ($node_old) = $node->get_aligned_nodes_of_type($self->orig_alignment_type);
    my ($node_src) = $node->get_aligned_nodes_of_type($self->src_alignment_type);
    my ($parent) = $node->get_eparents( {or_topological => 1} );
    my ($parent_old) = $parent->get_aligned_nodes_of_type($self->orig_alignment_type);
    my ($parent_src) = $parent->get_aligned_nodes_of_type($self->src_alignment_type);

    my $info = {};

    # smtout (old) and current (new) nodes info
    $self->node_info_getter->add_info($info, 'old', $node_old);
    $self->node_info_getter->add_info($info, 'new', $node);

    # src nodes need not be parent and child, so get info for both, and the edge
    $self->src_node_info_getter->add_info($info, 'nodesrc',   $node_src);
    $self->src_node_info_getter->add_info($info, 'parentsrc', $parent_src);
    $self->src_node_info_getter->add_edge_existence_info($info, 'srcedge', $node_src, $parent_src);
    
    return $info;
}

# changes the tag in the node and regebnerates the form correspondingly
# only a wrapper
sub regenerate_node {
    my ( $self, $node, $new_tag ) = @_;

    if (defined $new_tag) {
        $node->set_tag($new_tag);
    }

    return $self->formGenerator->regenerate_node( $node, $self->dont_try_switch_number );
}


1;

=head1 NAME 

Depfix::MLFix -- fixes errors using a machine learned correction model

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

