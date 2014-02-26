package Treex::Block::Depfix::EN2CS::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Block::Depfix::MLFix';

use Treex::Tool::Depfix::CS::FormGenerator;

has c_gen_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_gen_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has c_num_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_num_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has c_cas_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_cas_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has model_type => ( is => 'rw', isa => 'Str', default => 'maxent' );
# allowed values: maxent, nb, dt

use Treex::Tool::Depfix::CS::NodeInfoGetter;
use Treex::Tool::Depfix::EN::NodeInfoGetter;

override '_build_node_info_getter' => sub  {
    return Treex::Tool::Depfix::CS::NodeInfoGetter->new();
};

override '_build_src_node_info_getter' => sub  {
    return Treex::Tool::Depfix::EN::NodeInfoGetter->new();
};

override '_build_form_generator' => sub {
    my ($self) = @_;

    return Treex::Tool::Depfix::CS::FormGenerator->new();
};

override '_load_models' => sub {
    my ($self) = @_;

    my $model_params_gen = {
        config_file => $self->c_gen_config_file,
        model_file  => $self->c_gen_model_file,
    };
    my $model_params_num = {
        config_file => $self->c_num_config_file,
        model_file  => $self->c_num_model_file,
    };
    my $model_params_cas = {
        config_file => $self->c_cas_config_file,
        model_file  => $self->c_cas_model_file,
    };

    if ( $self->model_type eq 'maxent' ) {
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::MaxEntModel->new($model_params_cas);
    } elsif ( $self->model_type eq 'nb' ) {
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::NaiveBayesModel->new($model_params_cas);
    } elsif ( $self->model_type eq 'dt' ) {
        $self->_models->{c_gen} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_gen);
        $self->_models->{c_num} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_num);
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::DecisionTreesModel->new($model_params_cas);
    }

    return;
};

override '_predict_new_tags' => sub {
    my ($self, $node, $model_predictions) = @_;

    # old
    my $tag = $node->tag;
    my @categories = split //, $tag;
    my ($old_gen, $old_num, $old_cas) =
        ($categories[2], $categories[3], $categories[4]);

    # new
    my ($new_gen) = (keys %{$model_predictions->{c_gen}} );
    my ($new_num) = (keys %{$model_predictions->{c_num}} );
    my ($new_cas) = (keys %{$model_predictions->{c_cas}} );
    if ( !defined $new_gen ) {
        $new_gen = $old_gen;
    }
    if ( !defined $new_num ) {
        $new_num = $old_num;
    }
    if ( !defined $new_cas ) {
        $new_cas = $old_cas;
    }

    substr $tag, 2, 3, $new_gen.$new_num.$new_cas;

    return { $tag => 1 };
};


1;

=head1 NAME 

Depfix::EN2CS::MLFix -- fixes errors using a machine learned correction model,
with EN as the source language and CS as the target language

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

