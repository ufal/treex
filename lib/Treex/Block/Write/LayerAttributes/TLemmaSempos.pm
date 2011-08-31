package Treex::Block::Write::LayerAttributes::TLemmaSempos;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '' ] } );


# Return the t-lemma and sempos
sub modify {

    my ($self, $tlemma, $sempos) = @_;

    return if ( !defined($sempos) || !defined($tlemma) );

    my $sempos1 = $sempos;
    $sempos1 =~ s/\..*//;

    return ( $tlemma . '.' . $sempos1 );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::TLemmaSempos

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::TLemmaSempos->new();
    my $tlemma = 'čtyři';
    my $sempos = 'adj.quant.def';   

    # this now prints 'čtyři.adj'
    print $modif->modify( $tlemma, $sempos ); 

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<t_lemma> and C<gram/sempos>
attributes and returns the t-lemma concatenated with the first field of sempos.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
