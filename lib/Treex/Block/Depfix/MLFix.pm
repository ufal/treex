package Treex::Block::Depfix::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;
use Treex::Tool::Depfix::Model;
use Treex::Tool::Depfix::CS::FixLogger;
use List::Util "reduce";

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has src_alignment_type => ( is => 'rw', isa => 'Str', default => 'align_forward' );
has orig_alignment_type => ( is => 'rw', isa => 'Str', default => 'copy' );
has formGenerator => ( is => 'rw' );
# has _formGenerator => ( is => 'rw', isa => 'Treex::Tool::Depfix::FormGenerator' );
has _models => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
# has _models => ( is => 'rw', isa => 'HashRef[Treex::Tool::Depfix::Model]', default => sub { {} } );
has form_recombination => ( is => 'rw', isa => 'Bool', default => 1 );

has fixLogger => ( is => 'rw' );
has log_to_console => ( is => 'rw', isa => 'Bool', default => 1 );

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

sub process_anode {
    my ($self, $child) = @_;

    my $features = $self->get_features($child);
    if ( defined $features ) {
        my $new_tag = $self->predict_new_tag($child, $features);
        if ( defined $new_tag ) {
            $self->regenerate_node($child, $new_tag);
            $self->fixLogger->logfix2($child);
            #log_info (join ' ', (map { $_ . ':' . $features->{$_}  } keys %$features));
        }
    }

    return;
}

sub predict_new_tag {
    my ($self, $child, $features) = @_;

    # get predictions from models
    my $model_predictions = {};
    my @model_names = keys %{$self->_models};
    foreach my $model_name (@model_names) {
        my $model = $self->_models->{$model_name};
        $model_predictions->{$model_name} = $model->get_predictions($features);
    }

    # process predictions to get tag suggestions
    my $new_tags = $self->_predict_new_tags($child, $model_predictions);

    my $new_tag;
    if ( $self->form_recombination) {
        # recombinantion according to form
        my %forms = ();
        foreach my $tag (keys %$new_tags) {
            my $form = $self->formGenerator->get_form( $child->lemma, $tag );
            if (defined $form) {
                $forms{$form}->{score} += exp($new_tags->{$tag});
                $forms{$form}->{tags}->{$tag} = $new_tags->{$tag};
            }
        }
        my $message = 'MLFix (' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $new_tags->{$_}) }
                keys %$new_tags) ) . 
        ' ' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $forms{$_}->{score}) }
                keys %forms) ) .
        ')';
        $self->fixLogger->logfix1($child, $message);

        # find new form and tag
        my $new_form = reduce {
            $forms{$a}->{score} > $forms{$b}->{score} ? $a : $b
        } keys %forms;
        my $tags = $forms{$new_form}->{tags};
        $new_tag = reduce { $tags->{$a} > $tags->{$b} ? $a : $b } keys %$tags;
    } else {
        my $message = 'MLFix (' .
        (join ', ',
            (map { $_ . ':' . sprintf('%.2f', $new_tags->{$_}) }
                keys %$new_tags) ) . 
        ' ' .
        $self->fixLogger->logfix1($child, $message);

        $new_tag = reduce { $new_tags->{$a} > $new_tags->{$b} ? $a : $b }
            keys %$new_tags;        
    }

    if ( $new_tag ne $child->tag ) {
        return $new_tag;
    } else {
        return;
    }
}

sub _predict_new_tags {
    my ($self, $child, $model_predictions) = @_;

    log_fatal "Abstract method _predict_new_tag must be overridden!";

    return;
}

sub get_features {
    my ($self, $child) = @_;

    my $features;

    my ($parent) = $child->get_eparents( {or_topological => 1} );
    if ( !$parent->is_root() ) {

        my ($child_orig)  =
            $child->get_aligned_nodes_of_type($self->orig_alignment_type);
        my ($parent_orig)  =
            $parent->get_aligned_nodes_of_type($self->orig_alignment_type);
        
        # basic features
        $features = {
            # new = this tree
            new_c_lemma => $child->lemma,
            new_c_tag => $child->tag,
            new_c_afun => $child->afun,
            new_p_lemma => $parent->lemma,
            new_p_tag => $parent->tag,
            new_p_afun => $parent->afun,
            # orig tree
            c_lemma => $child_orig->lemma,
            c_tag => $child_orig->tag,
            c_afun => $child_orig->afun,
            p_lemma => $parent_orig->lemma,
            p_tag => $parent_orig->tag,
            p_afun => $parent_orig->afun,
            dir => ($child->precedes($parent) ? '/' : '\\'),
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
        $self->fill_language_specific_features($features, $child, $parent,
            $child_orig, $parent_orig);
    }

    return $features;
}

sub fill_language_specific_features {
    my ($self, $features, $child, $parent, $child_orig, $parent_orig) = @_;

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

