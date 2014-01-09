package Treex::Tool::Depfix::BaselineModel;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;   # for config
use Storable;     # for model
use PerlIO::gzip; # for training data

has config_file => ( is => 'rw', isa => 'Str', required => 1 );

has prediction => ( is => 'rw', isa => 'Str' );
has config => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);
    
    my $class = $config->[0]->{predict};
    $class =~ s/new/old/;
    $self->set_prediction($class);

    return;
}

sub get_best_prediction {
    my ($self, $instance_info) = @_;

    return $instance_info->{$self->prediction};
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
        
        my $prediction = $self->get_best_prediction(\%instance_info);

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

Treex::Tool::Depfix::BaselineModel -- a baseline class for a model for Depfix
corrections

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

