package Treex::Block::Write::LayerAttributes::CzechMLemmaTrunc;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Lexicon::CS;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'numbering' => ( isa => 'Bool', is => 'ro', default => 0 );


# Create the mode parameter out of the given parameter to new
sub BUILDARGS {

    my ( $class, @params ) = @_;

    return $params[0] if ( @params == 1 && ref $params[0] eq 'HASH' );

    if ( @params > 1 ) {
        log_fatal('CzechMLemmaTrunc: There must be one binary parameter to new().');
    }
    
    if ( @params == 1 ) {
        return { numbering => $params[0] };
    }
    return {};
}


sub modify_single {

    my ( $self, $lemma ) = @_;

    return undef if ( !defined($lemma) );
    
    return Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 - $self->numbering );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::CzechMLemmaTrunc

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::CzechMLemmaTrunc->new(); 

    print $modif->modify_all( 'Tatra-2_;R_^(vozidlo)' ); # prints 'Tatra' or 'Tatra-2' (depending on the parameter)

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes a Czech morphological lemma
and returns its truncated version (without explanations etc.).

=head1 PARAMETERS

=over

=item C<numbering>

If set to 1, the homonymous lemma numbers are retained. 0 is the default. May also be passed to the constructor 
as a single parameter.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
