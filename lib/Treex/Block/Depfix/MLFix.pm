package Treex::Block::Depfix::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;
use Treex::Tool::Depfix::Model;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'intersection' );
has formGenerator => ( is => 'rw' );
# has _formGenerator => ( is => 'rw', isa => 'Treex::Tool::Depfix::FormGenerator' );
has _models => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
# has _models => ( is => 'rw', isa => 'HashRef[Treex::Tool::Depfix::Model]', default => sub { {} } );

sub process_start {
    my ($self) = @_;

    $self->set_formGenerator($self->_build_form_generator());
    $self->_load_models();

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

sub process_anode {
    my ($self, $child) = @_;

    my $features = $self->get_features($child);
    if ( defined $features ) {
        my $new_tag = $self->predict_new_tag($child, $features);
        if ( defined $new_tag ) {
            $self->regenerate_node($child, $new_tag);
        }
    }

    return;
}

sub predict_new_tag {
    my ($self, $child, $features) = @_;

    my $model_predictions = {};
    my @model_names = keys %{$self->_models};
    foreach my $model_name (@model_names) {
        my $model = $self->_models->{$model_name};
        $model_predictions->{$model_name} = $model->get_predictions($features);
    }

    my $new_tag = $self->_predict_new_tag($child, $model_predictions);

    return $new_tag;
}

sub _predict_new_tag {
    my ($self, $child, $model_predictions) = @_;

    log_fatal "Abstract method _predict_new_tag must be overridden!";
    
    return;
}

sub get_features {
    my ($self, $child) = @_;

    my $features;

    my ($parent) = $child->get_eparents( {or_topological => 1} );
    if ( !$parent->is_root() ) {
        
        # basic features
        $features = {
            c_lemma => $child->lemma,
            c_tag => $child->tag,
            c_afun => $child->afun,
            p_lemma => $parent->lemma,
            p_tag => $parent->tag,
            p_afun => $parent->afun,
            dir => ($child->precedes($parent) ? '/' : '\\')
        };

        # aligned src nodes features
        my ($child_src)  =  $child->get_aligned_nodes_of_type($self->src_alignment_type);
        if ( defined $child_src ) {
            $features->{src_c_lemma} = $child_src->lemma;
            $features->{src_c_tag} = $child_src->tag;
            $features->{src_c_afun} = $child_src->afun;
        } else {
            $features->{src_c_lemma} = '';
            $features->{src_c_tag} = '';
            $features->{src_c_afun} = '';
 
        }
        my ($parent_src) = $parent->get_aligned_nodes_of_type($self->src_alignment_type);
        if ( defined $parent_src ) {
            $features->{src_p_lemma} = $parent_src->lemma;
            $features->{src_p_tag} = $parent_src->tag;
            $features->{src_p_afun} = $parent_src->afun;
        } else {
            $features->{src_p_lemma} = '';
            $features->{src_p_tag} = '';
            $features->{src_p_afun} = '';
 
        }
        if ( defined $child_src && defined $parent_src ) {
            if ( grep {
                    $_->id eq $parent_src->id
                } $child_src->get_eparents( {or_topological => 1} )
            ) {
                $features->{src_edge} = 1;
            } else {
                $features->{src_edge} = 0;
            }
        } else {
            $features->{src_edge} = -1;
        }

        # language specific features
        $self->fill_language_specific_features($features, $child, $parent);        
    }

    return $features;
}

sub fill_language_specific_features {
    my ($self, $features, $child, $parent) = @_;

    # to be overridden in subclasses,
    # especially filling morphological features

    return;
}

# changes the tag in the node and regebnerates the form correspondingly
# only a wrapper
sub regenerate_node {
    my ( $self, $node, $new_tag ) = @_;

    if (defined $new_tag) {
        $node->set_tag($new_tag);
    }

    return $self->formGenerator->regenerate_node( $node );
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

