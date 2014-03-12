package Treex::Tool::Depfix::Base;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;   # for config
has config_file => ( is => 'rw', isa => 'Str', required => 1 );
has config => ( is => 'rw' );

has baseline_prediction => ( is => 'rw', isa => 'Str' );

use PerlIO::gzip; # for testdata

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);
    
    # baseline: if predicting e.g. newchild_ccas, return oldchild_ccas
    # might be conjoined, e.g. new_node_cas|new_node_gen
    my $class = $config->[0]->{predict};
    $class =~ s/new/old/g;
    $self->set_baseline_prediction($class);

    return;
}

# This is THE method that actually implements the fix.
# To be overridden, obviously. (Now returns the baseline, i.e. the old value.)
sub get_predictions {
    my ($self, $instance_info) = @_;

    my $prediction = $self->get_baseline_prediction($instance_info);

    return { $prediction => 1 };
}

# This is THE method that actually implements the fix.
# To be overridden, obviously. (Now returns the baseline, i.e. the old value.)
sub get_best_prediction {
    my ($self, $instance_info) = @_;

    return $self->get_baseline_prediction($instance_info);
}

sub get_baseline_prediction {
    my ($self, $instance_info) = @_;

    return $self->fields2feature($instance_info, $self->baseline_prediction);
}

sub fields2feature {
    my ($self, $fields, $feature) = @_;

    # TODO pre-split these in advance
    my @feature_fields = split /\|/, $feature;
    return join '|', map { $fields->{$_} } @feature_fields;
}

sub test {
    my ($self, $testfile) = @_;

    my $all = 0;
    my $good = 0;
    
    my $true_positive = 0;
    my $true_negative = 0;
    my $false_positive = 0;
    my $false_negative = 0;
    my $wrong_positive = 0;

    open my $testing_file, '<:gzip:utf8', $testfile;
    while ( my $line = <$testing_file> ) {
        chomp $line;
        my @fields = split /\t/, $line;
        my %instance_info;
        @instance_info{ @{ $self->config->{fields} } } = @fields;
        
        my $prediction = $self->get_best_prediction(\%instance_info);
        my $baseline_prediction = $self->get_baseline_prediction(\%instance_info);
        my $true = $self->fields2feature(\%instance_info, $self->config->{predict});

        if ( $prediction eq $true ) {
            $good++;
            if ( $prediction eq $baseline_prediction ) {
                $true_negative++;
            } else {
                $true_positive++;
            }
        } else {
            if ( $prediction eq $baseline_prediction ) {
                $false_negative++;
            } elsif ( $true eq $baseline_prediction ) {
                $false_positive++;
            } else {
                $wrong_positive++;
            }
        }
        $all++;

        if ( $. % 10000 == 0) { log_info "Line $. processed"; }
    }
    close $testing_file;

    my $accuracy  = int($good / $all*100000)/1000;
    log_info "Accuracy: $accuracy %  ($good of $all; $true_positive TP, " .
    "$true_negative TN, $false_positive FP, $false_negative FN, $wrong_positive WP)";

    return $accuracy;
}

1;

=head1 NAME 

Treex::Tool::Depfix::Base -- a base class for a tool providing Depfix
corrections, such as a model or a rule

Also serves as the baseline, since it implements the methods so as to always
return the original value unchanged.

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

