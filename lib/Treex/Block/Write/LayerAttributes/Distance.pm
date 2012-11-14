package Treex::Block::Write::LayerAttributes::Distance;
use Moose;
use Treex::Core::Common;
use Scalar::Util qw(looks_like_number);

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'mode' => ( isa => enum( [ 'numeric', 'numericSigned', '3level', 'binary' ] ), is => 'ro', default => 'numeric' );


# Create the mode parameter out of the given parameter to new
sub BUILDARGS {

    my ( $class, @params ) = @_;

    return $params[0] if ( @params == 1 && ref $params[0] eq 'HASH' );

    if ( @params != 1 ) {
        log_fatal('Distance:There must be just one parameter to new(), allowed values: "numeric", "3level", "binary".');
    }
    return { mode => $params[0] };
}


sub modify_single {

    my ( $self, $ord1, $ord2 ) = @_;

    return undef if ( !List::MoreUtils::all { defined($_) && looks_like_number($_) } ( $ord1, $ord2 ) );

    if ( $self->mode eq '3level' ) {
        if ( abs( $ord1 - $ord2 ) <= 1 ) {
            return 'near';
        }
        elsif ( abs( $ord1 - $ord2 ) <= 4 ) {
            return 'close';
        }
        else {
            return 'far';
        }
    }
    elsif ( $self->mode eq 'binary' ) {
        return abs( $ord1 - $ord2 ) <= 1 ? 1 : 0;
    }
    elsif ( $self->mode eq 'numericSigned' ) {
        return $ord1 - $ord2;
    }
    else {
        return abs( $ord1 - $ord2 );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::Distance

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::Distance->new( 'numeric' ); 

    print $modif->modify_all( $node1->ord, $node2->ord ); # prints the topological distance b/t these two nodes

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes two numeric arguments 
and returns their distance (in four C<mode>s, see PARAMETERS). This is useful for node distances (e.g. the 
distance of a node to its parent etc.).

The constructor can take either the C<mode> value directly or enclosed in a hash reference.

=head1 PARAMETERS

=over

=item C<mode>

The mode this text modifier should be working in. The allowed values are:

=over

=item C<numeric>: the actual numeric distance (absolute value)

=item C<numericSigned>: the actual numeric distance, signed (first - second)

=item C<3level>: a three-level resolution -- a direct neighbor ('near') / max. 4 nodes away ('close') / farther ('far')

=item C<binary>: just tells if the first node is a direct neighbor of the second one

=back

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
