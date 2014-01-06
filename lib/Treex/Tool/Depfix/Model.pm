package Treex::Tool::Depfix::Model;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;   # for config
use Storable;     # for model
use PerlIO::gzip; # for training data

has config_file => ( is => 'rw', isa => 'Str', required => 1 );
has model_file => ( is => 'rw', isa => 'Str', required => 1 );

has config => ( is => 'rw' );
has model => ( is => 'rw' );

# for training (goes to training mode if training_file is set)
has training_file => ( is => 'rw', isa => 'Str', default => '' );

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);

    if ( $self->training_file ne '' ) {
        $self->set_model($self->_initialize_model());
    } else {
        $self->set_model($self->_load_model());
    }

    return;
}

## FOR RUNTIME ##

# override if needed
sub _load_model {
    my ($self) = @_;

    return Storable::retrieve( $self->model_file );
}

sub get_predictions {
    my ($self, $instance_info) = @_;

    my %features = map {
        $_ => $instance_info->{$_}
    } @{ $self->config->{features} };

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

    my %features = map {
        $_ => $instance_info->{$_}
    } @{ $self->config->{features} };

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

## FOR TRAINING ##

sub _initialize_model {
    my ($self) = @_;

    log_fatal "_initialize_model is abstract";

    return;
}

sub train_and_store {
    my ($self) = @_;

    log_info 'Seeing the training data...';
    $self->_training_loop();
    
    log_info 'Learning the model...';
    $self->_train_model();
    
    log_info 'Storing the model...';
    $self->_store_model();

    log_info 'Model trained and stored!';

    return;
}

sub _training_loop {
    my ($self) = @_;

    open my $training_file, '<:gzip:utf8', $self->training_file;
    while ( my $line = <$training_file> ) {
        chomp $line;
        my @fields = split /\t/, $line;
        my %instance_info;
        @instance_info{ @{ $self->config->{fields} } } = @fields;
        
        $self->see_instance(\%instance_info);

        if ( $. % 10000 == 0) { log_info "Line $. processed"; }
    }
    close $training_file;

    return;
}

sub see_instance {
    my ($self, $instance_info) = @_;

    my %features = map {
        $_ => $instance_info->{$_}
    } @{ $self->config->{features} };
    
    my $class = $instance_info->{ $self->config->{predict} };

    return $self->_see_instance(\%features, $class);
}

sub _see_instance {
    my ($self, $features, $class) = @_;

    log_fatal "_see_instance is abstract";    

    return;
}

# override if needed
sub _train_model {
    my ($self) = @_;

    # nothing done by default

    return;
}

# override if needed
sub _store_model {
    my ($self) = @_;

    Storable::store( $self->model, $self->model_file );

    return;
}

sub test {
    my ($self, $testfile) = @_;

    my $all = 0;
    my $good = 0;

    open my $testing_file, '<:gzip:utf8', $testfile;
    while ( my $line = <$testing_file> ) {
        chomp $line;
        my @fields = split /\t/, $line;
        my %instance_info;
        @instance_info{ @{ $self->config->{fields} } } = @fields;
        
        my $prediction = $self->_get_best_prediction(\%instance_info);

        my $true = $instance_info{ $self->config->{predict} };
        if ( $prediction eq $true ) {
            $good++;
        }
        $all++;

        if ( $. % 10000 == 0) { log_info "Line $. processed"; }
    }
    close $testing_file;

    my $accuracy  = int($good / $all*10000)/100;
    log_info "Accuracy: $accuracy%  ($good of $all)";

    return $accuracy;
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

