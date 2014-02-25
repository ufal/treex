package Treex::Tool::Depfix::DecisionTreesModel;
use Moose;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use Algorithm::DecisionTree;

override '_get_predictions' => sub {
    my ($self, $features) = @_;

    my @features_a = ();
    foreach my $feature (keys %$features) {
        my $value = $features->{$feature};
        if ($value eq '') {
            $value = '_nic_';
        }
        push @features_a, ($feature . '=>' . $value);
    }

    my $predictions = $self->model->{dt}->classify(
        $self->model->{root_node}, \@features_a);

    my $result = {};
    foreach my $label (keys %$predictions) {
        if ($label eq '_nic_') {
            $label = '';
        } elsif  ($label eq '_minus_') {
            $label = '-';
        }
        $result->{$label} = $predictions->{$label};
    }

    return $result;
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

