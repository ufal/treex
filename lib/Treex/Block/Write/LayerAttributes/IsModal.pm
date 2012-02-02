package Treex::Block::Write::LayerAttributes::IsModal;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

# Return 1 if the functor is an actant, 0 otherwise
sub modify_single {

    my ( $self, $deontmod ) = @_;

    return undef if ( !defined($deontmod) );

    return '0' if ( $deontmod =~ m/^(decl|nr)?$/ );
    return '1';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::IsModal

=head1 SYNOPSIS

    my $deontmod = 'decl';   
    my $modif = Treex::Block::Write::LayerAttributes::IsActant->new(); 
    print $modif->modify_all( $deontmod ); # prints '0'
    
    my $functor = 'fac';    
    print $modif->modify_all( $deontmod ); # prints '1'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes the C<deotmod> grammateme and returns
a 0/1 value indicating whether the given value is a non-default modality (i.e. a modal verb was involved).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
