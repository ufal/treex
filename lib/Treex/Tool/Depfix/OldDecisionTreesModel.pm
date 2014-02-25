package Treex::Tool::Depfix::OldDecisionTreesModel;
use Moose;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use AI::DecisionTree;

has max_depth => ( is => 'rw', isa => 'Num', default => 6 );

override '_get_predictions' => sub {
    my ($self, $features) = @_;

    # these DTs are single-best
    my $prediction = $self->_get_best_prediction($features);

    if ( defined $prediction ) {
        return { $prediction => 1 };
    } else {
        return {};
    }
};

override '_get_best_prediction' => sub {
    my ($self, $features) = @_;

    return $self->model->get_result(attributes => $features);
};

## FOR TRAINING ##

override '_initialize_model' => sub {
    my ($self) = @_;

    my $dt = new AI::DecisionTree;
    $dt->{noise_mode} = 'pick_best';
    $dt->{max_depth} = $self->max_depth;
    return $dt;
};

override '_see_instance' => sub {
    my ($self, $features, $class) = @_;

    $self->model->add_instance(
        attributes => $features, result => $class);

    return;
};

override '_train_model' => sub {
    my ($self) = @_;

    $self->model->train;

    return;
};

sub get_rules {
    my ($self) = @_;

    return $self->model->rule_statements();
}

1;

=head1 NAME 

Treex::Tool::Depfix::OldDecisionTreesModel -- a decision trees model for Depfix
corrections, based on L<AI::DecisionTree>.
Because of limitations of L<AI::DecisionTree>,
L<Treex::Tool::Depfix::DecisionTreesModel>, based on L<Algorithm::DecisionTree>,
should probably be used instead.
(But maybe not.)

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

