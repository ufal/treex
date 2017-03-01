package Treex::Block::MLFix::MarkByScikitLearn;
use Moose;
use Treex::Core::Common;
use utf8;

use Treex::Tool::MLFix::ScikitLearn;

extends 'Treex::Block::MLFix::Mark2Fix';

sub _load_models {
    my ($self) = @_;

	my $models_rf = $self->config->{models};

	log_fatal("No models listed in the configuration file") if !(%$models_rf);

	my %models = ();
	foreach my $model_name (keys %$models_rf) {
		my $model = Treex::Tool::MLFix::ScikitLearn->new(
			config_file => $self->config_file,
			model_file => $models_rf->{$model_name}
		);
		$models{$model_name} = $model;
	}

    return \%models;
}

sub _get_predictions {
    my ($self, $instances) = @_;

    my @model_predictions_array = map { {} } @$instances;

	my @model_names = keys %{$self->_models};
	foreach my $model_name (@model_names) {
		my $model = $self->_models->{$model_name};
		my $current_predictions_array = $model->get_predictions_array($instances);
		my $iterator = List::MoreUtils::each_arrayref(\@model_predictions_array, $current_predictions_array);
		while ( my ($model_predictions, $current_predictions) = $iterator->() ) {
            $current_predictions->{1} = 0 if !defined $current_predictions->{1};
			$model_predictions->{$model_name} = $current_predictions;
		}
	}

    return \@model_predictions_array;
}

1;

=head1 NAME 

Treex::Block::MLFix::MarkByScikitLearn -- Mark nodes that needs to by fixed using a ScikitLearn model

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

