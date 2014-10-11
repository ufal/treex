package Treex::Block::Write::LayerAttributes::TagWords;
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


# Build the return values' names
sub _build_retval_names {
    my ($self) = @_;
    my @names = ( '_POS' );
    foreach my $i ( 1 .. ( $self->feat_num ) ) {
        push @names, '_FEAT' . $i;
    }
    return \@names;
}

sub modify_single {

    my ( $self, $pos ) = @_;
    
    my @ret = ();

    return ( undef, map {undef} 1 .. $self->feat_num ) if ( !defined($pos) );

    my (@vals) = split (/\+/, $pos // '', ($self->feat_num + 1));
    #log_info($pos);
    #log_info(join(' -- ', @vals));
    #die();

    return ( map { $vals[$_] // '' } 0 .. ( $self->feat_num ) );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::TagWords

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
