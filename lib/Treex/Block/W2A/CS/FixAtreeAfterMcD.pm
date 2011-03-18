package Treex::Block::W2A::CS::FixAtreeAfterMcD;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    foreach my $a_node ( $a_root->get_descendants ) {
        if ( $a_node->afun eq "AuxX" || $a_node->afun eq "AuxG" ) {
            my @children = $a_node->get_children();
            my $ch       = $children[0];
            if ( defined $ch && $ch->is_member ) {

                # _Co under AuxX => change AuxX to Coord
                $a_node->set_afun('Coord');
            }
        }
    }

    my @root_children = grep { $_->afun ne "AuxK" } $a_root->get_children;
    foreach my $i ( 1 .. $#root_children ) {
        $root_children[$i]->set_parent( $root_children[0] );
    }

}

1;

=over

=item Treex::Block::W2A::CS::FixAtreeAfterMcD

Some hardwired fixes of McDonald parser output:
- AuxG or AuxX above coordinated (is_member) nodes changed to Coord
- McD sometimes generates trees with more then two children
(there should be only one effective root and final punctuation).
If it happens, everything is attached below the first root's child.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
