package Treex::Block::Write::LayerAttributes::CzechMorphCat;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => (
    default => sub {
        [
            '_MainPOS', '_SubPOS', '_Gen', '_Num',
            '_Cas',     '_PGe',    '_PNu', '_Per',
            '_Ten',     '_Gra',    '_Neg', '_Voi',
            '_Var'
        ];
        }
);

# Split Czech positional tag to attributes for all positions (except the two
# reserved ones), or gather attributes from the morphcat structure of a-nodes.
sub modify_single {

    my ( $self, $tag ) = @_;

    return ( '', '', '', '', '', '', '', '', '', '', '', '', '' ) if ( !$tag );

    my @values;

    # using the morphcat structure
    if ( ref $tag eq 'HASH' ) {
        foreach my $key (
            'pos', 'subpos', 'gender', 'number', 'case',
            'possgender', 'possnumber', 'person', 'tense',
            'grade', 'negation', 'voice'
            )
        {
            my $value = $tag->{$key};
            $value = '' if $value eq '.';
            push @values, $value;
        }
        push @values, '';    # variant is not included in morphcat
    }

    # using the positional tag
    else {
        foreach my $i ( 0 .. 11, 14 ) {
            push @values, substr( $tag, $i, 1 );
        }
    }
    return @values;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::CzechMorphCat

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::CzechMorphCat->new();
    my $tag = 'NNIS1-----A----';    
    
    print join(', ', $modif->modify_all( $tag )); 
    # prints 'N, N, I, S, 1, -, -, -, -, -, A, -, -, -, -' 

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes>
which takes the Czech positional morphological tag or the morphcat hashref
structure and returns all its meaningful positions as separate values.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
