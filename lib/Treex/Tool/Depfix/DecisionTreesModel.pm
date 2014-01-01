package Treex::Tool::Depfix::DecisionTreesModel;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use Algorithm::DecisionTree;
use Storable;

has dt_file => ( is => 'rw', isa => 'Str', required => 1 );
has dt => ( is => 'rw' );

override '_load_model' => sub {
    my ($self) = @_;

    # loading has 2 steps
    # 1. load Algorithm::DecisionTree object
    $self->set_dt(Storable::retrieve( $self->dt_file ));
    # 2. load the trained decision tree
    return Storable::retrieve( $self->model_file );
};

override 'get_predictions' => sub {
    my ($self, $features_hr) = @_;

    my @features_a = map {
        $self->feature2field->{$_} . '=>' . $features_hr->{$_}
    } @{$self->config->{features}};

    return $self->dt->classify($self->model, \@features_a);
};


1;

=head1 NAME 

Treex::Tool::Depfix::DecisionTreesModel -- a decision trees model for Depfix
corrections, based on L<Algorithm::DecisionTree>.

Currently using version 1.71 (AVIKAK/Algorithm-DecisionTree-1.71.tar.gz) because
it is compatible wit Perl 12.

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

