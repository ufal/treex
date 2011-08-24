package Treex::Block::P2A::TigerET;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub _terminals {
    my ($p_root) = @_;
    return grep defined $_->lemma, $p_root->get_descendants;
} # terminals


## Reads the estonian p-tree, builds corresponding a-tree.
sub process_zone {
    my $self   = shift;
    my $zone   = shift;
    my $p_root = $zone->get_ptree;
    my ($a_root, @anodes);
    if ($zone->has_atree) {
        $a_root = $zone->get_atree;
        @anodes = $a_root->get_descendants( { ordered => 1 } );
    } else {
        $a_root  = $zone->create_atree();
        @anodes = ();
        my $ord = 1;
        my %anode_from_terminal;
        foreach my $terminal (_terminals($p_root)) {
            my $anode = $a_root->create_child(
                {
                    form  => $terminal->form,
                    lemma => $terminal->lemma,
                    tag   => $terminal->wild->{pos}
                        . '/' . $terminal->wild->{morph},
                    ord   => $ord++,
                    afun  => 'NR',
                }
            );
            $anode_from_terminal{$terminal->id} = $anode;
            push @anodes, $anode;
        }
        foreach my $terminal (_terminals($p_root)) {
            if ('D' eq $terminal->is_head) {
                my ($parent) = grep 'H' eq $_->is_head, $terminal->get_siblings;
                $anode_from_terminal{$terminal->id}
                    ->set_parent($anode_from_terminal{$parent->id})
                        if $parent and $anode_from_terminal{$parent->id};
            }
        }
    }
} # process_zone




#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::P2A::TigerET

Converts Estonian Treebank in Tiger format to the style of the Prague
Dependency Treebank.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
