package Treex::Core::TredView::Common;

use Moose;
use Treex::Core::Log;

sub cur_node {
    my $node;

    # TODO: no warnings should be avoided as well as the whole re-blessing
    {
        no warnings 'once';
        $node = $TredMacro::this;
    }

    my $layer;
    if ( $node->type->get_structure_name =~ /(\S)-(root|node|nonterminal|terminal)/ ) {
        $layer = $1;
    }
    else {
        return;
    }
    bless $node, 'Treex::Core::Node::' . uc($layer);

    return $node;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Core::TredView::Common - Common methods related to TredView

=head1 DESCRIPTION

This packages provides methods that are useful for the whole TredView::* set of
packages.

=head1 METHODS

=head2 Public methods

=over 4

=item cur_node

=back

=head2 Private methods

=over 4

=back

=head1 AUTHOR

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

