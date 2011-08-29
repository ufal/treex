package Treex::Block::Write::LayerAttributes::CzechCoarseTag;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '' ] } ); 

# Czech POS tag simplified to POS&CASE (or POS&SUBPOS if no case)
sub modify {

    my ($tag) = @_;

    return if ( !defined($tag) );
    return '' if (!$tag);

    my $ctag;
    if ( substr( $tag, 4, 1 ) eq '-' ) {

        # no case -> PosSubpos
        $ctag = substr( $tag, 0, 2 );
    }
    else {

        # case -> PosCase
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

    $tag = 'NNIS1-----A----';   
    print Treex::Block::Write::LayerAttributes::CzechCoarseTag::modify( $tag ); # prints 'N1'
    $tag = 'VpYS---XR-AA---';
    print Treex::Block::Write::LayerAttributes::CzechCoarseTag::modify( $tag ); # prints 'Vp'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the Czech positional morphological tag
and makes a "coarse tag" out of it, which consists either of the coarse part-of-speech and case, if the given part-of-speech
can be declined or of the coarse and detailed part-of-speech.

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
