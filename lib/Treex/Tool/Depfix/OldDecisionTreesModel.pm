package Treex::Tool::Depfix::OldDecisionTreesModel;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Tool::Depfix::Model';

use AI::DecisionTree;
use Storable;

override '_load_model' => sub {
    my ($self) = @_;

    return Storable::retrieve( $self->model_file );
};

override '_get_predictions' => sub {
    my ($self, $features_ar) = @_;

    my %attributes = ();
    foreach my $feature (@$features_ar) {
        my ($k, $v) = split /:/, $feature, 2;
        $attributes{$k} = $v;
    }
    
    my $result = $self->model->get_result(attributes => \%attributes);
    my %predicitons;
    if ( defined $result ) {
        %predicitons = ( $result => 1 );
    } else {
        %predicitons = ( ); 
    }
    return \%predicitons;
};


1;

=head1 NAME 

Treex::Tool::Depfix::OldDecisionTreesModel -- a decision trees model for Depfix
corrections, based on L<AI::DecisionTree>.
Because of limitations of L<AI::DecisionTree>,
L<Treex::Tool::Depfix::DecisionTreesModel>, based on L<Algorithm::DecisionTree>,
should probably be used instead.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

