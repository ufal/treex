package Treex::Tool::ML::LinearRegression::Util;

use Moose;

sub extract_polyn_feats {
    my ($self, $x, $k) = @_;

    my @new_x = ();
    foreach my $feat (@$x) {
        for (my $i = 1; $i <= $k; $i++) {
            # add the i-th power of every feature into a feature set
            push @new_x, ( $feat ** $i );
        }
    }

    return \@new_x;
}

sub normalize {
    my ($self, $x, $means, $ranges) = @_;

    my @new_x = map {($x->[$_] - $means->[$_]) / $ranges->[$_]} (0 .. @$x-1);
    return \@new_x;
}

1;
