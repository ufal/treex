package Treex::Tool::Coreference::NodeFilter::Coord;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

sub is_coord_root {
    my ($node, $args) = @_;
    return 0 if ($node->get_layer ne 't');
    return ($node->is_coap_root && $node->functor ne "APPS");
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter::Coord

=head1 DESCRIPTION

A filter for coordinations.

=head1 METHODS

=over

=item my $bool = is_coord_root($tnode, $args)

Returns whether the input C<$tnode> is a coordination root or not.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

