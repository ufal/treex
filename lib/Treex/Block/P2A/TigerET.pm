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


sub _orphans {
    my ($node, $anode_from_pnode) = @_;
    my @orphans = map $anode_from_pnode->{$_->id} ? $_
                      : _orphans($_,$anode_from_pnode),
                  $node->get_children;
    return @orphans;
} # _orphans;


sub _left_neighbor {
    my $node = shift;
    my $parent = $node->get_parent;
    my @pchildren = $parent->get_children;
    my $index = 0;
    $index++ until $pchildren[$index] == $node;
    return $pchildren[$index - 1];
} # _left_neighbor

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
                    push @pheads, $child
                        if $child->is_head =~ /^(?:[HP]|Vm(?:ain)?)$/
                            or ('CO' eq $child->is_head
                                and grep 'CJT' eq $_->is_head, @children);
                }
                log_warn("Too many heads\t"
                         . join (' ', sort map $_->is_head, @children)
                         . "\t" . $pnode->get_address) if 1 < @pheads;
                my $phead = $pheads[-1];
                $phead = $children[0] if 1 == @children;

                # No head can be found. Try to search only among
                # "important" nodes.
                if (not $phead) {
                    my @candidates = grep $_->is_head !~ /^(?:--|FST|PNC|B)$/,
                                @children;
                    $phead = $candidates[0] if 1 == @candidates;
                }

                # numerical constructions of type A D
                if (not $phead
                    and 2 == @children
                    and my ($num) = grep { 'A' eq $_->is_head
                               and 'num' eq $_->wild->{pos}
                             } @children) {
                    $phead = $num;
                }

                # coordination without conjunction is not marked, find
                # the graphical symbol and make it the coordination
                my @cjt;
                if (not $phead
                    and @cjt = grep 'CJT' eq $_->is_head, @children
                    and @cjt > 1) {
                    my $coord = _left_neighbor($cjt[-1]);
                    if ($coord
                        and $coord->is_head
                        and 'punc' eq $coord->wild->{pos}) {
                        $phead = $coord;
                    } else {
                        $phead = $cjt[-1];
                        push @{ $a_root->wild->{coord} },
                            [map $anode_from_pnode{$_->id}->id, @cjt];
                    }
                }

                # no head was found, try to find it by phrase name
                if (not $phead) {
                    my $phrase = $pnode->wild->{tiger_phrase};
                    my %head_of_phrase
                        = ( pp   => '^(?:pst|prp)',
                            np   => '^n',
                            adjp => '^adj',
                            acl  => '^A');
                    my $find = $head_of_phrase{$phrase};
                    if ($find
                        and my @found = grep $_->wild->{pos} =~ /$find/
                                        || $_->is_head =~ /$find/, @children) {
                        $phead = $found[0] if 1 == @found;
                        log_info("PHRASE:\t$phrase / $find "
                                 . scalar @found . "\t"
                                 . $pnode->get_address);
                    }
                }

                if ($phead) {
                    my $ahead = $anode_from_pnode{$phead->id};
                    $anode_from_pnode{$pnode->id} = $ahead;
                    if ($ahead and $ahead->wild->{function} =~ /^[DH]$/
                        and $phead->get_parent->is_head
                        and $phead->get_parent->is_head !~ /^[DH]$/) {
                        $ahead->wild->{function} = $phead->get_parent->is_head;
                    }
                    foreach my $child (grep $_ != $phead, @children) {
                        my $achild = $anode_from_pnode{$child->id};
                        if ($achild and $ahead) {
                            $achild->set_parent($ahead);
                            $achild->wild->{function} = $child->is_head;

                        # The p-node does not project to a-node,
                        # because there was no head for its
                        # children. Make the a-head their head.
                        } elsif ($ahead) {
                            my @orphans = _orphans($child, \%anode_from_pnode);
                            log_info("ORPHANS\t" . scalar @orphans
                                     . "\t" . $child->get_address);
                            $anode_from_pnode{$_->id}->set_parent($ahead)
                                for @orphans;
                        }
                    }
                } else {
                    log_warn("No head found\t"
                             . $pnode->wild->{tiger_phrase} . ': '
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
