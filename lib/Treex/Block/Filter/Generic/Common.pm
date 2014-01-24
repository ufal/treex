package Treex::Block::Filter::Generic::Common;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub add_feature {
    my ( $self, $bundle, $feature ) = @_;

    my $previous = $bundle->attr( 'czeng/filter_features' );
    if ( defined $previous ) {
        $bundle->set_attr( 'czeng/filter_features', $previous . " ". $feature );
    } else {
        $bundle->set_attr( 'czeng/filter_features', $feature );
    }
    return 1;
}

sub get_features {
    my ( $self, $bundle ) = @_;
    if ( ! defined $bundle->attr( 'czeng/filter_features' ) ) {
        return undef;
    }
    my ( @features ) = split /\s+/, $bundle->attr( 'czeng/filter_features' );
    return @features;
}

sub get_final_score {
    my ( $self, $bundle ) = @_;
    return $bundle->attr( 'czeng/filter_score' );
}

sub set_final_score {
    my ( $self, $bundle, $score ) = @_;
    $bundle->set_attr( 'czeng/filter_score', $score );
}

sub quantize {
    my ( $self, $precision, $value, $max_value ) = @_;
    my $bucket = $precision * int( $value / $precision );
    if (defined $max_value && $bucket > $max_value) {
        $bucket = $max_value;
    }
    return $bucket;
}

sub quantize_given_bounds {
    my ( $self, $value, @bounds ) = @_;
    my $bucket = "min";
    for my $bound ( @bounds ) {
        if ( $value < $bound ) {
            last;
        } else {
            $bucket = $bound;
        }
    }
    return $bucket;
}

1;

=over

=item Treex::Block::Filter::Generic::Common

Common antecedent of filtering blocks.

=back

=cut

# Copyright 2011, 2014 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
