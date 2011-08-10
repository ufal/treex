package Treex::Block::T2T::StripCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $node ) = @_;

    $node->set_attr( 'coref_gram.rf', undef );
}

1;
__END__

=over

=item Treex::Block::T2T::StripCoref

Removes coreference links from tectogrammatical trees. For a purpose of
testing the coreference resolving.

=back

=cut

# Copyright 2011 Michal Novak
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
