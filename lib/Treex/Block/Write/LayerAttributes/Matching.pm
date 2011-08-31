package Treex::Block::Write::LayerAttributes::Matching;
use Moose;
use Treex::Core::Common;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( builder => '_build_return_values_names', lazy_build => 1 );

has 'types_regexps' => ( isa => 'ArrayRef', is => 'ro', required => 1 );

has 'data_types' => ( isa => 'ArrayRef', is => 'ro', required => 1 );

# Create the types_regexps and data_types parameters out of the given parameter to new
sub BUILDARGS {

    my ( $class, @params ) = @_;

    return $params[0] if ( @params == 1 && ref $params[0] eq 'HASH' );

    if ( @params != 1 || ref $params[0] ne 'ARRAY' || @{ $params[0] } != 2 ) {
        log_fatal('Matching:There must be just one parameter to new(), referencing a two-member array.');
    }
    my $ret = {};
    $ret->{types_regexps} = [ split( /\s+/, $params[0]->[0] ) ];
    $ret->{data_types}    = [ split( /\s+/, $params[0]->[1] ) ];
    return $ret;
}

# Take the types_regexps parameter and build the return values names
sub _build_return_values_names {

    my ($self) = @_;
    my @ret;

    foreach my $regexp ( @{ $self->types_regexps } ) {
        my $re_name = $regexp;
        $re_name =~ s/[^A-Za-z0-9_-]//g;
        $re_name = '_' . $re_name;

        # take each regexp with all datatypes
        push @ret, map { $re_name . '_' . $_ } @{ $self->data_types };

        # add a numeral saying how many children there are of this type
        push @ret, $re_name . '_Num';
    }
    return \@ret;
}

# Return the t-lemma and sempos
sub modify {

    my ( $self, $tags_str, @vals ) = @_;

    my @ret;
    my @tags = split / /, $tags_str;    # split the concatenated values of all POS tags
    @vals = map { [ split / /, $_ ] } @vals;    # split the concatenated values of all nodes for each datatype

    # for each tag regexp, find the matching indexes and get their concatenated values for all data types
    foreach my $regexp ( @{ $self->types_regexps } ) {
        my @idx = ();
        foreach my $i ( 0 .. ( @tags - 1 ) ) {
            push @idx, $i if ( $tags[$i] =~ m/$regexp/ );
        }

        push @ret, map { join ' ', @{$_}[@idx] } @vals;
        push @ret, scalar(@idx);
    }

    return @ret;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::Matching

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::Matching->new( '^N ^A ^J', 'lemma tag' );
    my $lemmas = 'geniální lingvista';
    my $tags = 'AAFP1----1A---- NNIS1-----A----';   
     
    # prints 'lingvista, NNIS1-----A----, 1, geniální, AAFP1----1A----, 1, , , 0'
    print join(', ', $modif->modify($tag, $lemma, $tag));  
    
=head1 DESCRIPTION

This modifier takes several attributes of a group of nodes (concatenated as single values) and for all attributes,
it filters out the values of nodes where the first attribute does not match the given regexp. It also appends a number
of matching nodes.

This is useful e.g. for filtering just nominal children, or just prepositions from C<aux.rf> and retrieving their
properties. 

There may be several regexps and therefore several sets of return values. The input regexps and attribute names
must be given to the constructor via the L<Treex::Block::Write::LayerAttributes> C<modifier_config> parameter
(as a two member array, or a hash containing the C<data_types> and C<types_regexps> members).    

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
