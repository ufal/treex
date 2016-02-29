package Treex::Tool::MLFix::Model;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Tool::MLFix::Base';

## FOR RUNTIME ##

sub get_predictions {
    my ($self, $instance_info) = @_;

	my $predictions = $self->_get_predictions($instance_info);
	if ( !defined $predictions ) {
        log_warn "No predictions generated, using the baseline instead.";
        $predictions = $self->get_baseline_prediction($instance_info);
		return { $predictions => 1 };
    }

    return $predictions;
}

sub _get_predictions {
    my ($self, $instance_info) = @_;

    log_fatal "_get_predictions is abstract";    

    return;
}

sub get_best_prediction {
    my ($self, $instance_info) = @_;

    my $prediction = $self->_get_best_prediction($instance_info);
    if ( !defined $prediction ) {
        log_warn "No prediction generated, using the baseline instead.";
        $prediction = $self->get_baseline_prediction($instance_info);
    }
    
    return $prediction;
}

# may be undef
# may be overridden if the model has a better way to do that
sub _get_best_prediction {
    my ($self, $instance_info) = @_;

    my $predictions = $self->_get_predictions($instance_info);
    my $best_prediction = undef;
    my $best_prediction_score = 0;
    foreach my $prediction (keys %$predictions) {
        if ( $predictions->{$prediction} > $best_prediction_score ) {
            $best_prediction = $prediction;
            $best_prediction_score = $predictions->{$prediction};
        }
    }

    return $best_prediction;
}

1;

=head1 NAME 

Treex::Tool::MLFix::Model -- a base class for a model for MLFix
corrections

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
