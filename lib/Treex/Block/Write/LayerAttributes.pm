package Treex::Block::Write::LayerAttributes;

use Moose::Role;
use Moose::Util::TypeConstraints;


has 'layer' => (
    isa => enum( [ 'a', 't', 'p', 'n' ] ),
    is => 'ro',
    required => 1
);

has 'attributes' => (
    isa      => 'Str',
    is       => 'ro',
    required => 1
);

# This is a parsed list of attributes, constructed from the attributes parameter.
has '_attrib_list' => (
    isa        => 'ArrayRef',
    is         => 'ro',
    builder    => '_build_attrib_list',
    lazy_build => 1
);

# Parse the attribute list given in parameters.
sub _build_attrib_list {
    my ($self) = @_;

    return [ split /\s+/, $self->attributes ];
}

sub process_zone {

    my $self = shift;
    my ($zone) = @_; # pos_validated_list won't work here

    if ( !$zone->has_tree( $self->layer ) ) {
        log_fatal( 'No tree for ' . $self->layer . ' found.' );
    }
    my $tree = $zone->get_tree( $self->layer );
    
    $self->_process_tree($tree);
    return 1;
}


sub _process_tree {
    log_fatal("Method _process_tree must be overridden for all Blocks with the LayerAttributes role.");
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different layers and different attributes. All blocks with this
role must override the C<_process_tree()> method.

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=item C<attributes>

A space-separated list of attributes (relating to the tree nodes on the specified layer) to be processed. 
This parameter is required.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
