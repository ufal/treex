package Treex::Block::Depfix::EN2CS::MLFix_nc;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Block::Depfix::MLFix';

use Treex::Tool::Depfix::CS::FormGenerator;

has c_num_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_num_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has c_cas_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_cas_model_file => ( is => 'rw', isa => 'Str', required => 1 );

has model_type => ( is => 'rw', isa => 'Str', default => 'odt' );
# allowed values: maxent, nb, dt, odt

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

    my $model_params_num = {
        config_file => $self->c_num_config_file,
        model_file  => $self->c_num_model_file,
    };
    my $model_params_cas = {
        config_file => $self->c_cas_config_file,
        model_file  => $self->c_cas_model_file,
    };

    if ( $self->model_type eq 'odt' ) {
        $self->_models->{c_num} =
        Treex::Tool::Depfix::OldDecisionTreesModel->new($model_params_num);
        $self->_models->{c_cas} =
        Treex::Tool::Depfix::OldDecisionTreesModel->new($model_params_cas);
    }

    return;
};


override 'predict_new_tag' => sub {
    my ($self, $node, $instance_info) = @_;

    my $model_predictions = {};
    my @model_names = keys %{$self->_models};
    foreach my $model_name (@model_names) {
        my $model = $self->_models->{$model_name};
        my $prediction = $model->get_best_prediction($instance_info);
        $model_predictions->{$model_name} = $prediction;
    }

    my $tag = $node->tag;
    my $nc = $model_predictions->{c_num} .  $model_predictions->{c_cas};
    substr $tag, 3, 2, $nc;
    
    $self->fixLogger->logfix1($node, "MLFix");
    return $tag;
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

