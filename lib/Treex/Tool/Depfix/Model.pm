package Treex::Tool::Depfix::Model;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;

has config_file => ( is => 'rw', isa => 'Str', required => 1 );
has model_file => ( is => 'rw', isa => 'Str', required => 1 );

has config => ( is => 'rw' );
has model => ( is => 'rw' );

has feature2field => ( is => 'rw', isa => 'HashRef', default => sub { {} } ); 

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);

    my $fields = $self->config->{fields};
    for (my $i = 0; $i < scalar(@$fields); $i++) {
        $self->feature2field->{$fields->[$i]} = $i;
    }

    $self->set_model($self->_load_model());
    
    return;
}

sub _load_model {
    my ($self) = @_;

    log_fatal "_load_model is abstract";

    return;
}

sub get_predictions {
    my ($self, $features_hr) = @_;

    my @features_a = map {
        $self->feature2field->{$_} . ":" . $features_hr->{$_}
    } @{$self->config->{features}};

    return $self->_get_predictions(\@features_a);
}

sub _get_predictions {
    my ($self, $features_ar) = @_;

    log_fatal "_get_predictions is abstract";    

    return ;
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

