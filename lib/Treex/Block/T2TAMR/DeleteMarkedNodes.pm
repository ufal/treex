package Treex::Block::T2TAMR::DeleteMarkedNodes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has '+selector' => ( isa => 'Str', default => 'amrConvertedFromT' );

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # look for all nodes, marked for deletion
    if ( defined $tnode->wild->{'special'} && $tnode->wild->{'special'} eq 'Delete' ) {

        # move all its children to its parent
        my $parent_node = $tnode->get_parent();
        foreach my $child_node ( $tnode->get_children ) {
            $child_node->set_parent($parent_node);
        }

        #print STDERR "Delete " . $tnode->t_lemma . "\n";
        #print STDERR "Modifier " . $tnode->wild->{'modifier'} . "\n";
        $tnode->remove();
    }
}

1;

=over

=item Treex::Block::T2TAMR::DeleteMarkedNodes

=back

=cut

# Copyright 2014

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
