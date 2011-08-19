package Treex::Block::A2T::StripCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text all/] ),
    required    => 1,
    default     => 'all',
);

sub process_tnode {
    my ( $self, $node ) = @_;

    my $type = $self->type;
    
    if ($type eq 'all') {
        $node->set_attr( 'coref_gram.rf', undef );
        $node->set_attr( 'coref_gram.rf', undef );
    }
    else {
        $node->set_attr( "coref_$type.rf", undef );
    }
}

1;
__END__

=over

=item Treex::Block::A2T::StripCoref

Removes coreference links from tectogrammatical trees. For a purpose of
testing the coreference resolving.

=back

=cut

# Copyright 2011 Michal Novak
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
