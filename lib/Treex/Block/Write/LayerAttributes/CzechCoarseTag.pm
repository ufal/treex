package Treex::Block::Write::LayerAttributes::CzechCoarseTag;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'use_case' => ( isa => 'Bool', is => 'ro', default => 1 );

# Create the mode parameter out of the given parameter to new
sub BUILDARGS {

    my ( $class, @params ) = @_;

    return $params[0] if ( @params == 1 && ref $params[0] eq 'HASH' );

    if ( @params != 1 ) {
        log_fatal('CzechCoarseTag:There must be just one binary parameter to new().');
    }
    return { use_case => $params[0] };
}

# Czech POS tag simplified to POS&CASE (or POS&SUBPOS if no case, or instructed not to use cases)
sub modify {

    my ( $self, $tag ) = @_;

    return undef if ( !defined($tag) );
    return '' if ( !$tag );

    my $ctag;

    # no case or set not to use it -> Pos + Subpos
    if ( substr( $tag, 4, 1 ) eq '-' || !$self->use_case ) {
        $ctag = substr( $tag, 0, 2 );
    }

    # has case -> Pos + Case
    else {
        $ctag = substr( $tag, 0, 1 ) . substr( $tag, 4, 1 );
    }

    return $ctag;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::CzechCoarseTag

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::CzechCoarseTag->new(); 
    my $tag = 'NNIS1-----A----';   
    print $modif->modify( $tag ); # prints 'N1'
    $tag = 'VpYS---XR-AA---';
    print $modif->modify( $tag ); # prints 'Vp'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the Czech positional morphological tag
and makes a "coarse tag" out of it, which consists either of the coarse part-of-speech and case, if the given part-of-speech
can be declined, or of the coarse and detailed part-of-speech.

=head1 PARAMETERS

=over 

=item C<use_case>

If set to 0, the case values are not used, even if the given part-of-speech has them. Default is 1. This parameter can
also be passed to the constructor as a single boolean value. 

=back 

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
