package Treex::Block::P2A::TigerET;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

sub _is_terminal {
    return defined $_[0]->lemma;
} # _is_terminal

sub _terminals {
    my ($p_root) = @_;
    return grep _is_terminal($_), $p_root->get_descendants;
} # terminals

{ my %rank;
sub rank {
    my $pnode = shift;
    my $proot = $pnode->get_root;
    if (not exists $rank{$pnode}) {
        undef %rank;
        $rank{$proot->id} = 0;
        $rank{$_->id} = 1 + $rank{$_->get_parent->id}
            for $proot->get_descendants;
    }
    return $rank{$pnode->id};
}} # rank

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
        my %anode_from_pnode;
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
            $anode_from_pnode{$terminal->id} = $anode;
            $anode->wild->{function} = $terminal->is_head;
            push @anodes, $anode;
        }
        foreach my $pnode (sort { rank($b) <=> rank($a) }
                           $p_root->descendants) {
            if (my @children = $pnode->get_children) {
                my @pheads;
                for my $child (@children) {
                    push @pheads, $child if $child->is_head =~ /^(?:[HP]|Vm(?:ain)?)$/
                                            or ('CO' eq $child->is_head
                                                and grep 'CJT' eq $_->is_head,@children);
                }
                log_warn("Too many heads\t"
                         . join (' ', sort map $_->is_head, @children)
                         . "\t" . $pnode->get_address) if 1 < @pheads;
                my $phead = $pheads[0];
                $phead = $children[0] if 1 == @children;
                if ($phead) {
                    my $ahead = $anode_from_pnode{$phead->id};
                    $anode_from_pnode{$pnode->id} = $ahead;
                    foreach my $child (grep $_ != $phead, @children) {
                        my $achild = $anode_from_pnode{$child->id};
                        if ($achild and $ahead) {
                            $achild->set_parent($ahead);
                            $achild->wild->{function} = $child->is_head;
                        }
                    }
                } else {
                    log_warn("No head found\t"
                             . join (' ', sort map $_->is_head, @children)
                             . "\t" . $pnode->get_address);
                }
            }
        }
    }
} # process_zone


#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::P2A::TigerET

Converts phrase-based Estonian Treebank in Tiger format to dependency format.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
