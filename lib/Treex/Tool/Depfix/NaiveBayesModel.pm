package Treex::Tool::Depfix::NaiveBayesModel;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use Algorithm::NaiveBayes;

override '_load_model' => sub {
    my ($self) = @_;

    return Algorithm::NaiveBayes->restore_state( $self->model_file );
};

override '_get_predictions' => sub {
    my ($self, $features_ar) = @_;

    my %features_hash = map { $_ => 1 } @$features_ar;
    return $self->model->predict(attributes => \%features_hash);
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

