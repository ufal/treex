package Treex::Tool::ML::LinearRegression::Util;

use Moose;

sub extract_polyn_feats {
    my ($self, $x, $k) = @_;

    #my @new_x = ();
    #foreach my $feat (@$x) {
    #    for (my $i = 1; $i <= $k; $i++) {
    #        # add the i-th power of every feature into a feature set
    #        push @new_x, ( $feat ** $i );
    #    }
    #}

    my @new_x = map { @$_ } $self->_construct_values( $x, $k );

    return \@new_x;
}

sub _construct_values {
    my ($self, $x, $k) = @_;

    if ($k == 1) {
        return ( [], map { [$_] } @$x);
    }

    my @values = $self->_construct_values($x, $k-1);

    my @values_unwrap = map { @$_ } @values;
    my @extended_values = (\@values_unwrap);
    for (my $i = 0; $i < @$x; $i++) {
        my @new_level = ();
        for (my $j = $i; $j < @values-1; $j++) { 
            push @new_level, map {map {$_ * $x->[$i]} @$_} $values[$j+1]; 
        }
        push @extended_values, \@new_level;
    }
    return @extended_values;
}

sub normalize {
    my ($self, $x, $means, $ranges) = @_;

    my @new_x = map {($x->[$_] - $means->[$_]) / $ranges->[$_]} (0 .. @$x-1);
    return \@new_x;
}

1;
