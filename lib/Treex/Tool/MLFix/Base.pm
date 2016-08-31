package Treex::Tool::MLFix::Base;
use Moose;
use Treex::Core::Common;
use utf8;

use YAML::Tiny;   # for config
use PerlIO::gzip; # for testdata

has config_file => (
	is => 'rw',
	isa => 'Str',
	required => 1 
);

has config => (
	is => 'rw'
);

has _baseline_prediction => (
	is => 'rw',
	lazy => 1,
	builder => '_build_baseline_prediction',
	documentation => 'Baseline: if predicting e.g. "new_node_*", return "old_node*"'
);

sub _build_baseline_prediction {
	my ($self) = @_;

	return map { (my $out = $_) =~ s/new/old/; $out;} @{ $self->config->{predict} };
}

sub BUILD {
    my ($self) = @_;

    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );
    $self->set_config($config->[0]);
    
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

    return $self->fields2values($instance_info, $self->_baseline_prediction);
}

sub fields2values {
    my ($self, $instance_info, $fields) = @_;

	my @values = map { $instance_info->{$_} } @$fields;
    return \@values;
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

    open(my $testing_fh, '<:gzip:utf8', $testfile) or log_fatal("Cannot open file $testfile");
    while ( my $line = <$testing_fh> ) {
        chomp $line;
        my @fields = split /\t/, $line;
        my %instance_info;
        @instance_info{ @{ $self->config->{fields} } } = @fields;
        
		# TODO: compare whole prediction or individual 'predict' fields?

        my $prediction = join "\|", @{ $self->get_best_prediction(\%instance_info) };
        my $baseline_prediction = join "\|", @{ $self->get_baseline_prediction(\%instance_info) };
        my $true = join "\|", @{ $self->fields2values(\%instance_info, $self->config->{predict}) };

        if ( $prediction eq $true ) {
            $good++;
            if ( $prediction eq $baseline_prediction ) {
                $true_negative++;
                log_info "MLFix TRUENEG $prediction";
            } else {
                $true_positive++;
                log_info "MLFix TRUEPOS $baseline_prediction -> $prediction";
            }
        } else {
            if ( $prediction eq $baseline_prediction ) {
                $false_negative++;
                log_info "MLFix FALSENEG $baseline_prediction !-> $true";
            } elsif ( $true eq $baseline_prediction ) {
                $false_positive++;
                log_info "MLFix FALSEPOS $baseline_prediction -> $prediction";
            } else {
                $wrong_positive++;
                log_info "MLFix WRONGPOS $baseline_prediction -> $prediction !-> $true";
            }
        }
        $all++;

        if ( $. % 10000 == 0) { log_info "Line $. processed"; }
    }
    close $testing_fh;

    my $accuracy  = int(($good / $all)*100000)/1000;
    log_info "Accuracy: $accuracy %  ($good of $all; $true_positive TP, " .
    "$true_negative TN, $false_positive FP, $false_negative FN, $wrong_positive WP)";

    return $accuracy;
}

1;

=head1 NAME 

Treex::Tool::MLFix::Base -- a base class for a tool providing MLFix
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

