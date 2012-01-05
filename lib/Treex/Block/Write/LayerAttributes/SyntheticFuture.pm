package Treex::Block::Write::LayerAttributes::SyntheticFuture;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

# Return the t-lemma and sempos
sub modify_single {

    my ( $self, $lemma ) = @_;

    return undef if ( !defined($lemma) );

    $lemma =~ s/_s[ei]$//;

    return '1' if ( $lemma =~ /^(běžet|být|hrnout|jet|jít|letět|lézt|nést|růst|téci|vézt)$/ );
    return '0';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::SyntheticFuture

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::IsActant->new(); 

    my $lemma = 'jít'
    print $modif->modify_all( $lemma ); # prints '1'

    my $lemma = 'chodit'
    print $modif->modify_all( $lemma ); # prints '0'

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes> which takes a C<t-lemma> and returns
a 0/1 value indicating whether the given lemma usually expresses futuer using synthetic forms with the prefix 'po/pů'
instead of the regular compound future with the auxiliary 'být'.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
