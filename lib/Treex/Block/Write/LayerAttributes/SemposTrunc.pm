package Treex::Block::Write::LayerAttributes::SemposTrunc;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '_1', '_2' ] } );

# Sempos is truncated to the first and first + second field
sub modify {

    my ($sempos) = @_;

    return if ( !defined($sempos) );
    return ( '', '' ) if ( !$sempos );

    my $sempos1 = $sempos;
    my $sempos2 = $sempos;
    $sempos1 =~ s/\..*//;
    $sempos2 =~ s/\.([^.]*)\..*/.$1/;

    return ( $sempos1, $sempos2 );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::SemposTrunc

=head1 SYNOPSIS

    $sempos = 'adj.quant.def';   
    print join ' ', Treex::Block::Write::LayerAttributes::SemposTrunc::modify( $sempos ); # prints 'adj adj.quant'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<gram/sempos> argument and
returns two values: the first field of the argument and the first + second field.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
