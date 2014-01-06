package Treex::Tool::Depfix::MaxEntModel;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use AI::MaxEntropy;

override '_load_model' => sub {
    my ($self) = @_;

    return AI::MaxEntropy::Model->new( $self->model_file );
};

override '_get_predictions' => sub {
    my ($self, $features) = @_;

    my %predictions = map {
        $_ => exp($self->model->score($features => $_))
    } $self->model->all_labels;

    return \%predictions;
};

## FOR TRAINING ##

override '_initialize_model' => sub {
    my ($self) = @_;

    return AI::MaxEntropy->new;
};

override '_see_instance' => sub {
    my ($self, $features, $class) = @_;

    $self->model->see($features => $class);

    return;
};

override '_train_model' => sub {
    my ($self) = @_;

    $self->model->learn;

    return;
};

override '_store_model' => sub {
    my ($self) = @_;

    $self->model->save($self->model_file);

    return;
};

1;

=head1 NAME 

Treex::Tool::Depfix::MaxEntModel -- a maximum entropy model for Depfix
corrections

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

