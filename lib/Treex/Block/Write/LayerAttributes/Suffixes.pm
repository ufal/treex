package Treex::Block::Write::LayerAttributes::Suffixes;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => (
    builder    => '_build_return_values_names',
    lazy_build => 1
);

has 'lengths' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1
);

has '_lengths_list' => (
    isa        => 'ArrayRef[Int]',
    is         => 'ro',
    builder    => '_build_lengths_list',
    lazy_build => 1
);

# Parse the 'lengths' parameter to create a list of lengths
# to cut off as suffixes.
sub _build_lengths_list {
    my ( $self ) = @_;

    my @list;
    foreach my $len_spec ( split /[,\s]+/, $self->lengths ) {
        if ( $len_spec =~ /-/ ) {
            my ( $from, $to ) = split /-/, $len_spec;
            push @list, $from .. $to;
        }
        else {
            push @list, $len_spec;
        }
    }
    return \@list;
}

# Return the list of variables defined by this attribute modifier.
sub _build_return_values_names {
    my ( $self ) = @_;

    my @ret = map { '_Suf' . $_ } @{ $self->_lengths_list };
    return \@ret;
}

# Create the suffixes of the desired lengths
sub modify_single {

    my ( $self, $str ) = @_;
    
    my @ret;
    foreach my $suf_len ( @{ $self->_lengths_list } ) {
        if ( !defined($str) ) {    # undef yields undef
            push @ret, undef;
        }
        elsif ( $suf_len > length($str) ) {    # string too long -> whole
            push @ret, $str;
        }
        else {                                 # the desired suffix
            push @ret, substr( $str, -$suf_len );
        }
    }
    
    return @ret;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::Suffixes

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::Suffixes->new(
            { lengths => '1-3,7' }
        );
    print join ", ", $modif->modify_all( 'STRING' ); # 'G, NG, ING, STRING' 

=head1 DESCRIPTION

Return suffixes of the given string of specified length(s).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, 
Charles University in Prague

This module is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.
