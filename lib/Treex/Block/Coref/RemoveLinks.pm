package Treex::Block::Coref::RemoveLinks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'type' => ( is => 'ro', isa => enum([qw/all gram text/]), default => 'all' );

sub process_tnode {
    my ( $self, $tnode ) = @_;

#    if ($self->type eq 'expressed') {
#        return if ($tnode->is_generated);
#    }

    if ($self->type eq 'text') {
        $tnode->set_attr( 'coref_text.rf', undef );
    }
    elsif ($self->type eq 'gram') {
        $tnode->set_attr( 'coref_gram.rf', undef );
    }
    else {
        $tnode->set_attr( 'coref_gram.rf', undef );
        $tnode->set_attr( 'coref_text.rf', undef );
    }
}

1;
__END__

=over

=item Treex::Block::Coref::RemoveLinks

Removes coreference links from tectogrammatical trees. For a purpose of
testing the coreference resolving.

=back

=cut

# Copyright 2011, 2015 Michal Novak
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
