package Treex::Block::Write::LayerParameterized;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Treex::Core::Log;


requires '_process_tree';


has 'layer' => ( isa => enum( [ 'a', 't', 'p', 'n' ] ), is => 'ro', required => 1 );


# the main method
sub process_zone {

    my ($self, $zone) = @_;    # pos_validated_list won't work here

    if ( !$zone->has_tree( $self->layer ) ) {
        log_fatal( 'No tree for ' . $self->layer . '-layer found.' );
    }
    my $tree = $zone->get_tree( $self->layer );

    $self->_process_tree($tree);
    return 1;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerParameterized

=head1 DESCRIPTION

A Moose role for Write blocks that may be configured to use different layers. All blocks with this
role must override the C<_process_tree()> method, which will be called for each tree at layer given
in the C<layer> parameter.

=head1 PARAMETERS

=over

=item C<layer>

The annotation layer to be processed (i.e. C<a>, C<t>, C<n>, or C<p>). This parameter is required. 

=back

=head1 SEE ALSO

=over 

=item L<Treex::Block::Write::AttributeParameterized>

It is possible to combine this role with the C<AttributeParameterized> role to 
support also the work with different node attributes; please note that the C<with>
clause for this role must go BEFORE the C<with> clause of the C<AttributeParameterized> 
role. 

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
