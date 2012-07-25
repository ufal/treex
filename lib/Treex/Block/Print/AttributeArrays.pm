package Treex::Block::Print::AttributeArrays;

use Moose;
use Treex::Core::Common;
use autodie;

with 'Treex::Block::Write::LayerParameterized';
with 'Treex::Block::Write::AttributeParameterized';


has 'attr_sep' => ( isa => 'Str', is => 'ro', default => ' ' );

has '_data' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] }  );

# A dummy build method so that the 'before' modifier of AttributeParameterized can be used
sub BUILD {
}

sub _process_tree() {

    my ( $self, $tree ) = @_;

    my @nodes = $tree->get_descendants( { ordered => 1 } );
    my @values = map { join $self->attr_sep, @{ $self->_get_info_list($_) } } @nodes;
    
    $self->_set_data( \@values );
}


around 'process_zone' => sub {
    
    my $orig = shift;
    my $self = shift;
    
    $self->$orig(@_);
    
    return $self->_data;   
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::AttributeArrays

=head1 SYNOPSIS

    my $attr_extract = Treex::Block::Print::AttributeArrays->new( {layer => 'a', attributes => 'tag'} );    
    my @zone_tags = $attr_extract->process_zone( $zone );

=head1 DESCRIPTION

This is a simple wrapper for the L<Treex::Block::Write::AttributeParameterized> and 
L<Treex::Block::Write::LayerParameterized> roles which allow other blocks to gather arrays of 
given attributes out of different zones and use them in some other way than printing alone. 

=head1 ATTRIBUTES

=over

=item C<attr_sep>

The separator character for the individual attribute values for one node. Space (" ") is the default.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
