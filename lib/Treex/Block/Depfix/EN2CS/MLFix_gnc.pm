package Treex::Block::Depfix::EN2CS::MLFix_gnc;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Block::Depfix::MLFix';

has config_file => ( is => 'rw', isa => 'Str', required => 1 );
has model_file => ( is => 'rw', isa => 'Str', required => 1 );

has model_type => ( is => 'rw', isa => 'Str', default => 'maxent' );
# allowed values: maxent, nb, dt, odt, baseline

use Treex::Tool::Depfix::CS::NodeInfoGetter;
override '_build_node_info_getter' => sub  {
    return Treex::Tool::Depfix::CS::NodeInfoGetter->new();
};

use Treex::Tool::Depfix::EN::NodeInfoGetter;
override '_build_src_node_info_getter' => sub  {
    return Treex::Tool::Depfix::EN::NodeInfoGetter->new();
};

use Treex::Tool::Depfix::CS::FormGenerator;
override '_build_form_generator' => sub {
    my ($self) = @_;

    return Treex::Tool::Depfix::CS::FormGenerator->new();
};

override '_load_models' => sub {
    my ($self) = @_;

    my $model_params = {
        config_file => $self->config_file,
        model_file  => $self->model_file,
    };
    
    if ( $self->model_type eq 'maxent' ) {
        $self->_models->{gnc} =
            Treex::Tool::Depfix::MaxEntModel->new($model_params);
    } elsif ( $self->model_type eq 'nb' ) {
        $self->_models->{gnc} =
            Treex::Tool::Depfix::NaiveBayesModel->new($model_params);
    } elsif ( $self->model_type eq 'dt' ) {
        $self->_models->{gnc} =
            Treex::Tool::Depfix::DecisionTreesModel->new($model_params);
    } elsif ( $self->model_type eq 'odt' ) {
        $self->_models->{gnc} =
            Treex::Tool::Depfix::OldDecisionTreesModel->new($model_params);
    } elsif ( $self->model_type eq 'baseline' ) {
        $self->_models->{gnc} =
            Treex::Tool::Depfix::Base->new({config_file=>$self->config_file});
    }
    
    return;
};

override '_predict_new_tags' => sub {
    my ($self, $child, $model_predictions) = @_;

    my $tag = $child->tag;
    my %new_tags = ();
    foreach my $gnc (keys %{$model_predictions->{gnc}} ) {
        my $score = $model_predictions->{gnc}->{$gnc};
        $gnc =~ s/\|//g;
        substr $tag, 2, 3, $gnc;
        $new_tags{$tag} = $score;
    }

    return \%new_tags;
};

1;

=head1 NAME 

Depfix::EN2CS::MLFix_gnc -- fixes errors using a machine learned correction model,
with EN as the source language and CS as the target language

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

