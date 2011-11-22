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


#------------------------------------------------------------------------------
# Call this function for a p-node that does not project to any a-node, i.e.
# a nonterminal that does not have a head. All a-nodes in its subtree are
# orphans because we do not have a head to attach them to. The function returns
# the list of the orphaned a-nodes.
#------------------------------------------------------------------------------
sub _orphans {
    my ($pnode, $anode_from_pnode) = @_;
    # Having a corresponding a-node means:
    # either it is a terminal
    # or it is a nonterminal and we have been able to determine its head.
    my @orphans = map $anode_from_pnode->{$_->id} ? $_ : _orphans($_,$anode_from_pnode),
                  $pnode->get_children;
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
        # Prepare a-nodes for all terminal p-nodes.
        foreach my $terminal (_terminals($p_root)) {
            my $conll_feat = $terminal->wild->{morph} or '';
            $conll_feat =~ s/,/|/g;
            my $anode = $a_root->create_child(
                {
                    form  => $terminal->form,
                    lemma => $terminal->lemma,
                    tag   => $terminal->wild->{pos} . '/' . $terminal->wild->{morph},
                    'conll/cpos'   => $terminal->wild->{pos},
                    'conll/pos'    => $terminal->wild->{pos},
                    'conll/feat'   => $conll_feat,
                    'conll/deprel' => $terminal->edgelabel,
                    ord   => $ord++,
                }
            );
            $anode_from_pnode{$terminal->id} = $anode;
            $anode->wild->{function} = $terminal->edgelabel;
            push @anodes, $anode;
        }
        # Figure out dependencies between a-nodes.
        foreach my $pnode (sort { rank($b) <=> rank($a) } $p_root->descendants) {
            if (my @children = $pnode->get_children) {
                my $phead = find_head($pnode, @children);
                if ($phead) {
                    # Attach the non-head children to the head in the a-tree.
                    my $ahead = $anode_from_pnode{$phead->id};
                    # Associate the parent nonterminal with the same a-node as the head child.
                    $anode_from_pnode{$pnode->id} = $ahead;
                    if ($ahead)
                    {
                        if ($ahead->wild->{function} =~ /^[DH]$/
                            and $phead->get_parent->edgelabel()
                            and $phead->get_parent->edgelabel() !~ /^[DH]$/)
                        {
                            $ahead->wild->{function} = $phead->get_parent->edgelabel();
                        }
                        # Loop over all children (nonterminals and terminals) of the current nonterminal p-node.
                        foreach my $child (grep $_ != $phead, @children) {
                            my $achild = $anode_from_pnode{$child->id};
                            if ($achild) {
                                $achild->set_parent($ahead);
                                $achild->wild->{function} = $child->edgelabel();
                            } else {
                                # The child nonterminal does not project to any a-node because we were not able to find its head.
                                # All a-nodes corresponding to nodes in its subtree are orphans.
                                # Make the current a-head their head.
                                my @orphans = _orphans($child, \%anode_from_pnode);
                                log_info("ORPHANS\t" . scalar @orphans . "\t" . $child->get_address);
                                $anode_from_pnode{$_->id}->set_parent($ahead)
                                    for @orphans;
                            }
                        }
                    }
                    else
                    {
                        log_warn("No a-head for p-head ".$phead->form()."\t".$phead->get_address());
                    }
                } else {
                    my $edgelabels = join(' ', sort map $_->edgelabel(), @children);
                    log_warn("No head found\t" . $pnode->phrase() . ": $edgelabels\t" . $pnode->get_address);
                }
            }
        }
    }
} # process_zone



#------------------------------------------------------------------------------
# Determines the head among the children of a p-node.
#------------------------------------------------------------------------------
sub find_head
{
    my $pnode = shift;
    my @children = @_;
    my @pheads;
    # The main functions denoting the head are:
    # H ... head
    # P ... predicator
    # The head of coordination is the coordinating conjunction ('CO').
    for my $child (@children) {
        my $edgelabel = $child->edgelabel();
        push @pheads, $child
            if $edgelabel =~ /^(?:[HP]|Vm(?:ain)?)$/
                or ('CO' eq $edgelabel
                    and grep 'CJT' eq $_->edgelabel(), @children);
    }
    # There should be just one head.
    if(scalar(@pheads)>1) {
        my $edgelabels = join (' ', sort map $_->edgelabel(), @children);
        log_warn("Too many heads\t$edgelabels\t" . $pnode->get_address());
    }
    my $phead = $pheads[-1];
    $phead = $children[0] if 1 == @children;

    # No head found. Try to search only among "important" nodes.
    if (not $phead) {
        my @candidates = grep $_->edgelabel() !~ /^(?:--|FST|PNC|B)$/, @children;
        $phead = $candidates[0] if 1 == @candidates;
    }

    # numerical constructions of type A D
    if (not $phead
        and 2 == @children
        and my ($num) = grep { 'A' eq $_->edgelabel()
                   and 'num' eq $_->wild->{pos}
                 } @children) {
        $phead = $num;
    }

    # multiword conjunction A SUB
    if (not $phead
        and 2 == @children
        and 'A:SUB' eq join ':', sort map $_->edgelabel(), @children) {
        $phead = $children[0];
    }

    # coordination without conjunction is not marked, find
    # the graphical symbol and make it the coordination
    my @cjt;
    if (not $phead
        and @cjt = grep 'CJT' eq $_->edgelabel(), @children
        and @cjt > 1) {
        my $coord = _left_neighbor($cjt[-1]);
        if ($coord
            and $coord->edgelabel()
            and $coord->wild->{pos}
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
        my $phrase = $pnode->phrase();
        if(!$phrase)
        {
            log_warn("Missing phrase label: ".$pnode->get_address());
            $phrase = 'UNKNOWN';
        }
        my %head_of_phrase
            = ( pp   => '^(?:pst|prp)',
                np   => '^n',
                adjp => '^adj',
                acl  => '^A');
        my $find = $head_of_phrase{$phrase};
        if ($find
            and my @found = grep $_->wild->{pos} && $_->wild->{pos} =~ /$find/
                            || $_->edgelabel() && $_->edgelabel() =~ /$find/, @children) {
            $phead = $found[0] if 1 == @found;
            log_info("PHRASE:\t$phrase / $find " . scalar @found . "\t" . $pnode->get_address);
        }
    }

    return $phead;
}



#-------------------------------------------------------------------------------

1;

=over

=item Treex::Block::P2A::TigerET

Converts phrase-based Estonian Treebank in Tiger format to dependency format.

=back

=cut

# Copyright 2011 Jan Štěpánek <stepanek@ufal.mff.cuni.cz>, Daniel Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
