package Treex::Tool::Depfix::Model;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;

has config_file => ( is => 'rw', isa => 'Str', required => 1 );
has model_file => ( is => 'rw', isa => 'Str', required => 1 );

has config => ( is => 'rw' );
has model => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);

    $self->set_model($self->_load_model());
    
    return;
}

sub _load_model {
    my ($self) = @_;

    log_fatal "_load_model is abstract";

    return;
}

sub get_predictions {
    my ($self, $instance_info) = @_;

    my %features = map { $_ => $instance_info->{$_}  } @{$self->config->features};

    return $self->_get_predictions(\%features);
}

sub _get_predictions {
    my ($self, $features) = @_;

    log_fatal "_get_predictions is abstract";    

    return;
}

# may be undef
sub get_best_prediction {
    my ($self, $instance_info) = @_;

    my %features = map { $_ => $instance_info->{$_}  } @{$self->config->features};

    return $self->_get_best_prediction(\%features);
}

# may be overridden if the model has a better way to do that
sub _get_best_prediction {
    my ($self, $features) = @_;

    my $predictions = $self->_get_predictions($features);
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

Treex::Tool::Depfix::Model -- a base class for a model for Depfix
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

