package Treex::Block::Eval::AtreeUASWithConfInterval;
use Moose;
use Treex::Core::Common;
use POSIX qw(ceil floor);
use Math::Complex;
use Math::CDF;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'eval_is_member' => ( is => 'rw', isa => 'Bool', default => 0 );

my $number_of_nodes;
my %same_as_ref;
my %accuracy_by_node;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $ref_zone = $bundle->get_zone( $self->language, $self->selector );
    my @ref_parents = map { $_->get_parent->ord } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @ref_is_member = map { $_->is_member ? 1 : 0 } $ref_zone->get_atree->get_descendants( { ordered => 1 } );
    my @compared_zones = grep { $_ ne $ref_zone && $_->language eq $self->language } $bundle->get_all_zones();

    $number_of_nodes += @ref_parents;

    foreach my $compared_zone (@compared_zones) {
        my @parents = map { $_->get_parent->ord } $compared_zone->get_atree->get_descendants( { ordered => 1 } );
        my @is_member = map { $_->is_member ? 1 : 0 } $compared_zone->get_atree->get_descendants( { ordered => 1 } );

        if ( @parents != @ref_parents ) {
            log_fatal 'There must be the same number of nodes in compared trees';
        }
        my $label = $compared_zone->get_label;
        my $label1 = $label.'-regardless-is_member';

        foreach my $i ( 0 .. $#parents ) {
            my $ind_acc;
            if ( $parents[$i] == $ref_parents[$i] && ( !$self->eval_is_member || $is_member[$i] == $ref_is_member[$i] ) ) {
                $same_as_ref{$label}++;
                push @{$accuracy_by_node{$label}}, 1;
            }
            else {
                push @{$accuracy_by_node{$label}}, 0;
            }
            # If the main score includes is_member evaluation, provide the weaker evaluation as well.
            if ( $self->eval_is_member ) {
                if ( $parents[$i] == $ref_parents[$i] ) {
                    $same_as_ref{$label1}++;
                    push @{$accuracy_by_node{$label1}}, 1;
                }
                else {
                    push @{$accuracy_by_node{$label1}}, 0;
                }
            }            
        }
    }
}

END {
#    print "total\t$number_of_nodes\n";

#    foreach my $zone_label ( sort keys %same_as_ref ) {
#        my $str_out = sprintf("%-50s %8s/%-8s %-10.3f",$zone_label, $same_as_ref{$zone_label},$number_of_nodes, ( $same_as_ref{$zone_label} / $number_of_nodes ));
        #print "$zone_label\t$same_as_ref{$zone_label}/$number_of_nodes\t" . ( $same_as_ref{$zone_label} / $number_of_nodes ) . "\n";
#        print $str_out . "\n";
#    }
    
#    print "\n=============\n"; 

    # The following number indicates the size of the data(accuracy results)
    # from which confidence interval is calculated.
        
    my $num_groups = 20;

    foreach my $key (keys %accuracy_by_node) {

        my @acc_by_groups = get_accuracies_of_sub_data(\@{$accuracy_by_node{$key}}, $num_groups);
        
        # Confidence interval estimation
        my $mean = calculate_mean(\@acc_by_groups);
        my $std = calculate_std(\@acc_by_groups, $mean);
        my $confint = calculate_confidence_interval($num_groups, $mean, $std);

        my $str_out = sprintf("%-50s %-10.3f (+/-)%-10.3f",$key, $mean, $confint);
        print $str_out . "\n";        
    }
}

1;

# The whole result set is divided into the size of $num_groups and the 
# accuracy for each is calculated and returned as an array.
sub get_accuracies_of_sub_data {
    my $ref_acc_array_by_node = shift;
    my $num_sub_groups = shift;
    my @cross_accuracy = ();
    my @accuracy_data = @{$ref_acc_array_by_node};
    my $size_of_sub_group = floor(@accuracy_data / $num_sub_groups);
    foreach my $i (1..$num_sub_groups) {
        my $start = ($i-1)*$size_of_sub_group;    
        my $end = (($i * $size_of_sub_group) -1);
        if ($i == $num_sub_groups) {
            if ($end < $#accuracy_data) {
                $end = $#accuracy_data;
            }
        }
        my %count;
        for (my $j = $start; $j<= $end; $j++) {
            $count{$accuracy_data[$j]}++;
        }
        my $acc_sub_group = $count{1} / ($count{0} + $count{1});
        push @cross_accuracy, $acc_sub_group;
    }
    return @cross_accuracy;
}

# This subroutine will calculate the mean of a vector
sub calculate_mean {
    my $data_ref = shift;
    my @data = @{$data_ref};
    my $sum = 0.0;
    my $mean = 0.0;
    foreach my $val (@data) {
        $sum += $val;
    }
    
    # mean calculation
    $mean = $sum /scalar(@data);
    
    return $mean;
}

# This routine will return the standard deviation of a given data vector
# and its mean
sub calculate_std {
    my $data_ref = shift;
    my $avg = shift;
    my @data = @{$data_ref};
    my $std = 0.0;
        
    my $var = 0.0;
    foreach my $val (@data) {
        $var = $var + (($val-$avg) ** 2);
    }
    
    # standard deviation
    $std = sqrt((1 / (scalar(@data)-1)) * $var);
    
    return $std;
}

# This routine will return the confidence interval in the form of a single value.
# The mean would fall within that interval with 95% probability.
# The data is assumed to be coming from Normal Distribution.
sub calculate_confidence_interval {
    my $n = shift;
    my $mean = shift;
    my $std = shift;
    
    # conf interval:  ( mean-err, mean+err )
    my $err = 0.0;
    my $z = &Math::CDF::qnorm(0.975);
    $err =  ($z * $std) / sqrt($n);
    
    return $err;
}

=over

=item Treex::Block::Eval::AtreeUAS

Measure similarity (in terms of unlabeled attachment score) of a-trees in all zones
(of a given language) with respect to the reference zone specified by selector.

The output will have three fields

system : accuracy : confidence interval

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, David Marecek, Loganathan Ramasamy

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
