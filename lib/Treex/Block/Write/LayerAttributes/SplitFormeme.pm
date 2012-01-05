package Treex::Block::Write::LayerAttributes::SplitFormeme;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [ '_POS', '_RJ', '_form' ] } );

# The formeme is split into three parts: the part-of-speech, preposition or subjunction and form
sub modify_single {

    my ( $self, $formeme ) = @_;

    return ( undef, undef, undef ) if ( !defined($formeme) );
    return ( '',    '',    '' )    if ( !$formeme );

    my $pos  = $formeme;
    my $rj   = $formeme;
    my $form = $formeme;

    $pos =~ s/:.*$//;
    $rj = ( $rj =~ m/^.*:(([^\+]*)\+).*$/ ? $2 : "" );
    $form =~ s/^.*[:\+]//;

    return ( $pos, $rj, $form );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::SplitFormeme

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::SplitFormeme->new();
    my $formeme = 'n:k+3';   
    print join ' ', $modif->modify_all( $formeme ); # prints 'n k 3'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<formeme> value and 
splits it, returning three values: the part-of-speech, the subjunction or preposition, and the form of the 
word.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
