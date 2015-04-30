package Treex::Block::A2T::StripCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'persist' => ( is => 'ro', isa => enum([qw/none gram text expressed/]), default => 'none' );

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($self->persist eq 'expressed') {
        return if (!$tnode->is_generated);
    }

    if ($self->persist eq 'text') {
        $tnode->set_attr( 'coref_gram.rf', undef );
    }
    elsif ($self->persist eq 'gram') {
        $tnode->set_attr( 'coref_text.rf', undef );
    }
    else {
        $tnode->set_attr( 'coref_gram.rf', undef );
        $tnode->set_attr( 'coref_text.rf', undef );
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

# Copyright 2011, 2015 Michal Novak
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
