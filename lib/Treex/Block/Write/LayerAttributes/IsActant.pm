package Treex::Block::Write::LayerAttributes::IsActant;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

# Return 1 if the functor is an actant, 0 otherwise
sub modify_single {

    my ( $self, $functor ) = @_;

    return undef if ( !defined($functor) );

    return '0' if ( $functor !~ m/^(ACT|PAT|ADDR|ORIG|EFF|CPHR|DPHR)$/ );
    return '1';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::IsActant

=head1 SYNOPSIS

    my $functor = 'RSTR';   
    my $modif = Treex::Block::Write::LayerAttributes::IsActant->new(); 
    print $modif->modify_all( $functor ); # prints '0'
    
    my $functor = 'ACT';    
    print $modif->modify_all( $functor ); # prints '1'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<functor> and returns
a 0/1 value indicating whether the given functor is an actant (ACT, PAT, ORIG, ADDR, EFF).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
