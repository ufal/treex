package Treex::Block::Write::LayerAttributes::CoNLLMorphCat;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => (
    builder    => '_build_retval_names',
    lazy_build => 1
);

has 'feat_num' => (
    isa     => 'Int',
    is      => 'ro',
    default => 1
);

has 'cpos_chars' => (
    isa     => 'Int',
    is      => 'ro',
    default => 1
);

# Build the return values' names
sub _build_retval_names {
    my ($self) = @_;
    my @names = ( '_POS', '_CPOS' );
    foreach my $i ( 1 .. ( $self->feat_num ) ) {
        push @names, '_FEAT' . $i;
    }
    return \@names;
}

sub modify_single {

    my ( $self, $pos, $feats ) = @_;
    
    my @ret = ();

    return ( undef, undef, map {undef} 1 .. $self->feat_num ) if ( !defined($pos) );

    my $cpos = $self->cpos_chars > 0 ? substr( $pos, 0, $self->cpos_chars ) : $pos;
    my @feats = split /\|/, $feats // '', $self->feat_num;

    return ( $pos, $cpos, map { $feats[$_] // '' } 0 .. ( $self->feat_num - 1 ) );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::CoNLLMorphCat

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::CoNLLMorphCat->new(
            {feat_num => 5, cpos_chars => 1}
            );
    
    print join(', ', $modif->modify_all( 'V', 'trans|ovt|1of2of3|ev' )); 
    # prints 'V, V, trans, ovt, 1of2of3, ev' 

=head1 DESCRIPTION

A text modifier for blocks using L<Treex::Block::Write::LayerAttributes>
which takes the CoNLL POS tag and features and returns it in an array.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
