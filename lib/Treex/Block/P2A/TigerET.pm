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
            push @anodes, $anode;
        }
        foreach my $pnode (sort { rank($b) <=> rank($a) }
                           $p_root->descendants) {
            if (my @children = $pnode->get_children) {
                my ($phead) = grep $_->is_head =~ /^(?:[HP]|Vm(?:ain)?|CO)$/,
                              @children;
                $phead = $children[0] if 1 == @children;
                if ($phead) {
                    my $ahead = $anode_from_pnode{$phead->id};
                    $anode_from_pnode{$pnode->id} = $ahead;
                    foreach my $child (grep $_ != $phead, @children) {
                        my $achild = $anode_from_pnode{$child->id};
                        if ($achild and $ahead) {
                            $achild->set_parent($ahead);
                            set_afun($achild, $ahead, $child->is_head);
                        }
                    }
                }
            }
        }
    }
} # process_zone

sub set_afun {
    my ($achild, $ahead, $func) = @_;
    my $afun;
    if ('D' eq $func and $ahead->tag =~ m{^(?:n|prop)/}) {
        $afun = 'Atr';
    } elsif ('A' eq $func) {
        $afun = 'Adv';
    } elsif ('O' eq $func) {
        $afun = 'Obj';
    } elsif ('S' eq $func) {
        $afun = 'Sb';
    } elsif ('FST' eq $func) {
        $afun = 'AuxK';
    }
    $achild->set_afun($afun) if $afun;
} # set_afun



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
