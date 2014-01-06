package Treex::Tool::Depfix::NaiveBayesModel;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use Algorithm::NaiveBayes;
use Algorithm::NaiveBayes::Model::Frequency;    

override '_load_model' => sub {
    my ($self) = @_;

    return Algorithm::NaiveBayes->restore_state( $self->model_file );
};

override '_get_predictions' => sub {
    my ($self, $features) = @_;

    my %features_hash = map {
        $_ . ':' . $features->{$_} => 1
    } keys %$features;
    
    return $self->model->predict(attributes => \%features_hash);
};

## FOR TRAINING ##

override '_initialize_model' => sub {
    my ($self) = @_;

    return Algorithm::NaiveBayes->new;
};

override '_see_instance' => sub {
    my ($self, $features, $class) = @_;

    my %features_hash = map {
        $_ . ':' . $features->{$_} => 1
    } keys %$features;
    
    $self->model->add_instance(
        attributes => \%features_hash, label => $class);

    return;
};

override '_train_model' => sub {
    my ($self) = @_;

    $self->model->train;

    return;
};

override '_store_model' => sub {
    my ($self) = @_;

    $self->model->save_state($self->model_file);

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

