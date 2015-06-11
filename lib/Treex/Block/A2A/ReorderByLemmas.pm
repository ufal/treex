package Treex::Block::A2A::ReorderByLemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use autodie;

has mt_selector => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => 'selector of the zone with MT-output (machine translations)'
);

has mt_language => ( is  => 'rw', isa => 'Str', lazy_build => 1 );

sub _build_mt_language {
    my ($self) = @_;
    return $self->language;
}

# TODO: also for PrahpraseSimple
sub sl {
    my ($lemma) = @_;

    $lemma =~ s/[-_].+$//;    # ???

    return $lemma;
}

sub process_bundle {
    my ($self, $bundle, $bundleNo) = @_;
    
    # reference counts of lemmas
    my %ref_count = ();
    {
        my $ref_zone = $bundle->get_zone(
            $self->language, $self->selector);
        my $ref_atree = $ref_zone->get_atree();
        my @ref_anodes = $ref_atree->get_descendants({ordered => 1});
        for my $ref_anode (@ref_anodes) {
            $ref_count{sl($ref_anode->lemma)}++;
        }
        
        # lowercase first node unless its lemma is capitalized
        my $first_node = $ref_anodes[0];
        if (lcfirst($first_node->lemma) eq $first_node->lemma) {
            $first_node->set_form(lc($first_node->form));
        }
    }
    
    # MT ord of lemmas
    my %mt_ord = ();
    {
        my $mt_zone = $bundle->get_zone(
            $self->mt_language, $self->mt_selector);
        my $mt_atree = $mt_zone->get_atree();
        my @mt_anodes = $mt_atree->get_descendants();
        for my $mt_anode (@mt_anodes) {
            my $lemma = sl($mt_anode->lemma);
            if (defined $ref_count{$lemma} && $ref_count{$lemma} == 1) {
                # once in reference
                if (!defined $mt_ord{$lemma}) {
                    # first time in MT
                    $mt_ord{$lemma} = $mt_anode->ord;
                } else {
                    # special value saying "appears multiple times in MT" 
                    $mt_ord{$lemma} = -1;                
                }
            }
        }
    }
    
    # MT ords of reference subtrees;
    # for each node, store into wild:
    # mt_ord_sum = sum of MT ords of subtree nodes
    # mt_ord_count = number of subtree nodes that have a definet MT ord
    {
        my $ref_zone = $bundle->get_zone(
            $self->language, $self->selector);
        my $ref_atree = $ref_zone->get_atree();
        my @ref_anodes = $ref_atree->get_children();
        for my $ref_anode (@ref_anodes) {
            $self->subtree_mt_ord_recursive($ref_anode, \%mt_ord);
        }
    }
    
    # Let Treex::Core::Block call process_anode on each a-node of the reference zone
    $self->SUPER::process_bundle($bundle, $bundleNo);
    return;
}

# MT ords of reference subtrees;
# for each node, store into wild:
# mt_ord = my MT ord
# mt_ord_sum = sum of MT ords of subtree nodes
# mt_ord_count = number of subtree nodes that have a defined MT ord
sub subtree_mt_ord_recursive {
    my ( $self, $anode, $mt_ord ) = @_;

    my $mt_ord_count = 0;
    my $mt_ord_sum = 0;
    
    # children, recursively
    my @children = $anode->get_children();
    for my $child (@children) {
        $self->subtree_mt_ord_recursive($child, $mt_ord);
        $mt_ord_count += $child->wild->{mt_ord_count};
        $mt_ord_sum += $child->wild->{mt_ord_sum};
    }
    
    # me
    my $my_mt_ord = $mt_ord->{sl($anode->lemma)};
    if (defined $my_mt_ord && $my_mt_ord != -1) {
        $mt_ord_count += 1;
        $mt_ord_sum += $my_mt_ord;
        $anode->wild->{mt_ord} = $my_mt_ord;
    } else {
        $anode->wild->{mt_ord} = -1;
    }

    # store
    $anode->wild->{mt_ord_count} = $mt_ord_count;
    $anode->wild->{mt_ord_sum} = $mt_ord_sum;
        
    return;
}

sub process_anode {
    my ( $self, $parent ) = @_;

    # (actually children and parent)
    my @children = $parent->get_children({ordered => 1, add_self => 1});
    my $before = join ' ', map { $_->lemma } @children;
    
    # compute average MT ords of child subtrees
    my %id2avgmtord = ();
    {
        my $avgmtord = 0;
        for my $anode (@children) {
            if ($anode->id eq $parent->id) {
                # the parent
                if ($anode->wild->{mt_ord} > 0) {
                    # use only the mt ord of the parent, not of the subtree
                    $avgmtord = $anode->wild->{mt_ord};
                }
            } elsif ($anode->wild->{mt_ord_count} > 0) {
                # a child with defined subtree mt ord
                $avgmtord = $anode->wild->{mt_ord_sum} / $anode->wild->{mt_ord_count};
            }
            # else undefined mt ord:
            # keep value from previous interation
            # to keep the current node together with its left sibling
            
            # add a small bit to prefer keeping the original order in case of ties
            $id2avgmtord{$anode->id} = $avgmtord + $anode->ord/1000;
        }
    }
    
    # reorder by average mt_ords of the subtrees
    {
        my @ids_sorted = sort {$id2avgmtord{$a} <=> $id2avgmtord{$b}} (keys %id2avgmtord);
        my $document = $parent->get_document;
        my $prev_node = $document->get_node_by_id(shift @ids_sorted);
        for my $this_node (map { $document->get_node_by_id($_) } @ids_sorted) {
            if ($this_node->id eq $parent->id) {
                # shifting the parent
                $this_node->shift_after_subtree($prev_node, {without_children => 1});
            } elsif ($prev_node->id eq $parent->id) {
                # shifting after the parent
                $this_node->shift_after_node($prev_node);
            } else {
                # child nodes
                $this_node->shift_after_subtree($prev_node);
            }
            $prev_node = $this_node;
        }
    }

    {
        my $after = join ' ', map { $_->lemma } $parent->get_children({ordered => 1, add_self => 1});
        if ($before ne $after) {
            log_info "Reordering $before -> $after";
        }
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::ReorderByLemmas - change word order in reference to resemble MT-output

=head1 USAGE

 A2A::ReorderByLemmas mt_selector=tectomt selector=reference language=cs

=head1 DESCRIPTION

Input: a-trees of reference translation and machine translation
Output: modified reference translation a-tree

For each reference node, that has more than one child node,
we compute the average MT ord for the subtree of each of the child nodes,
and then sort the child nodes by these.
The MT ord of a reference node is the ord of a node with the same lemma in MT;
for simplicity, we use this lemma-based alignment,
and we take into account only lemmas that appear exactly once
in both reference and MT.
In case of ties, we favour to keep the original ordering.
In case of nodes with undefined subtree MT ord
(no mathcing lemma),
we let them follow their original left sibling.

We do not account for non-projectivities.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
