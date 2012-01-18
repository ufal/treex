package Treex::Block::Write::LayerAttributes::FirstChar;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

sub modify_single {

    my ( $self, $tag ) = @_;

    return ( undef ) if ( !defined($tag) );
    return '' if ($tag eq '');
    return substr( $tag, 0, 1 );
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::FirstChar

=head1 DESCRIPTION

Given a string, this attribute modifier returns its first character (or an empty string, if given an empty string,
or an undefined value if the input is not defined).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
