package Treex::Block::T2A::DeleteGeneratedNodes;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

Readonly my $LEMMAS_TO_REMOVE => {
    '#AsMuch'  => 1,
    '#Benef'   => 1,
    '#Cor'     => 1,
    '#EmpNoun' => 1,
    '#EmpVerb' => 1,
    '#Equal'   => 1,
    '#Forn'    => 1,
    '#Gen'     => 1,
    '#Idph'    => 1,
    '#Oblfm'   => 1,
    '#QCor'    => 1,
    '#Rcp'     => 1,
    '#Separ'   => 1,
    '#Some'    => 1,
};    # the t-lemmas of the nodes to be deleted

Readonly my $FUNCTORS_PRIORITY => {
    'ACMP'   => 5,
    'ACT'    => 9,
    'ADDR'   => 7,
    'ADVS'   => 10,
    'AIM'    => 5,
    'APP'    => 5,
    'APPS'   => 10,
    'ATT'    => 1,
    'AUTH'   => 5,
    'BEN'    => 5,
    'CAUS'   => 5,
    'CNCS'   => 5,
    'CM'     => 1,
    'COMPL'  => 5,
    'COND'   => 5,
    'CONFR'  => 10,
    'CONJ'   => 10,
    'CONTRA' => 10,
    'CONTRD' => 5,
    'CPHR'   => 10,
    'CPR'    => 5,
    'CRIT'   => 5,
    'CSQ'    => 10,
    'DENOM'  => 10,
    'DIFF'   => 5,
    'DIR1'   => 5,
    'DIR2'   => 5,
    'DIR3'   => 5,
    'DISJ'   => 10,
    'DPHR'   => 10,
    'EFF'    => 6,
    'EXT'    => 5,
    'FPHR'   => 1,
    'GRAD'   => 10,
    'HER'    => 5,
    'ID'     => 1,
    'INTF'   => 1,
    'INTT'   => 5,
    'LOC'    => 5,
    'MANN'   => 5,
    'MAT'    => 9,
    'MEANS'  => 5,
    'MOD'    => 1,
    'OPER'   => 10,
    'ORIG'   => 6,
    'PAR'    => 10,
    'PARTL'  => 10,
    'PAT'    => 8,
    'PREC'   => 1,
    'PRED'   => 10,
    'REAS'   => 10,
    'REG'    => 5,
    'RESL'   => 5,
    'RESTR'  => 5,
    'RHEM'   => 1,
    'RSTR'   => 5,
    'SUBS'   => 5,
    'TFHL'   => 5,
    'TFRWH'  => 5,
    'THL'    => 5,
    'THO'    => 5,
    'TOWH'   => 5,
    'TPAR'   => 5,
    'TSIN'   => 5,
    'TTILL'  => 5,
    'TWHEN'  => 5,
    'VOCAT'  => 10
};    # functors priority for collapsing the children under the most important one
      # (highest priority: roots of various structures, then actants - ACT > PAT > ADDR > rest, then modifiers,
      # least - rhematizers and similar)

Readonly my $FUNCTORS_HIERARCHY => {
    'ACMP'   => 5,
    'ACT'    => 1,
    'ADDR'   => 3,
    'ADVS'   => 5,
    'AIM'    => 5,
    'APP'    => 5,
    'APPS'   => 1,
    'ATT'    => 5,
    'AUTH'   => 5,
    'BEN'    => 5,
    'CAUS'   => 5,
    'CNCS'   => 5,
    'CM'     => 5,
    'COMPL'  => 5,
    'COND'   => 5,
    'CONFR'  => 1,
    'CONJ'   => 1,
    'CONTRA' => 1,
    'CONTRD' => 5,
    'CPHR'   => 1,
    'CPR'    => 4,
    'CRIT'   => 5,
    'CSQ'    => 1,
    'DENOM'  => 1,
    'DIFF'   => 5,
    'DIR1'   => 5,
    'DIR2'   => 5,
    'DIR3'   => 5,
    'DISJ'   => 1,
    'DPHR'   => 1,
    'EFF'    => 3,
    'EXT'    => 5,
    'FPHR'   => 1,
    'GRAD'   => 1,
    'HER'    => 5,
    'ID'     => 1,
    'INTF'   => 1,
    'INTT'   => 5,
    'LOC'    => 5,
    'MANN'   => 5,
    'MAT'    => 3,
    'MEANS'  => 5,
    'MOD'    => 1,
    'OPER'   => 1,
    'ORIG'   => 3,
    'PAR'    => 1,
    'PARTL'  => 1,
    'PAT'    => 1,
    'PREC'   => 1,
    'PRED'   => 1,
    'REAS'   => 1,
    'REG'    => 5,
    'RESL'   => 5,
    'RESTR'  => 5,
    'RHEM'   => 5,
    'RSTR'   => 5,
    'SUBS'   => 5,
    'TFHL'   => 5,
    'TFRWH'  => 5,
    'THL'    => 5,
    'THO'    => 5,
    'TOWH'   => 5,
    'TPAR'   => 5,
    'TSIN'   => 5,
    'TTILL'  => 5,
    'TWHEN'  => 5,
    'VOCAT'  => 1
};    # functors hierarchy -- determines which of two functors (parent-child) gets removed

has '+language' => ( required => 1 );

# Remember what links to which a-node for the current tree
has '_a_links' => ( isa => 'HashRef', is => 'rw' );

# The lexicon for the current language
has '_lexicon' => ( isa => 'Str', is => 'rw', builder => '_load_lexicon', lazy_build => 1 );

# Already processed nodes (so that they're not processed twice)
has '_processed' => ( isa => 'HashRef', is => 'rw' );

# Nodes that get deleted at the end.
has '_deleted' => ( isa => 'HashRef', is => 'rw' );

# MAIN
sub process_ttree {

    my ( $self, $troot ) = @_;

    $self->_set_processed( {} );
    $self->_set_deleted( {} );
    $self->_gather_a_links($troot);
    $self->_process_subtree($troot);
    $self->_delete_marked($troot);
    $self->_check_corefs($troot);
    return;
}

# Load the lexicon for the right language
sub _load_lexicon {

    my ($self) = @_;

    my $lexicon = 'Treex::Tools::Lexicon::' . uc( $self->language );
    ( my $file = $lexicon ) =~ s|::|/|g;
    require $file . '.pm';
    return $lexicon;
}

# (Recursively) processes a subtree by DFS, looking for nodes to be removed and removing them.
sub _process_subtree {

    my ( $self, $tnode ) = @_;

    # Do not process already processed or even deleted nodes
    if ( $self->_deleted->{$tnode} or $self->_processed->{$tnode} ) {
        return;
    }

    my @children = $tnode->get_children( { ordered => 1 } );

    foreach my $child (@children) {

        $self->_process_subtree($child);

        # this child might have gotten deleted in the meantime
        next if ( $self->_deleted->{$child} ); 

        if ( $child->is_generated and ( $child->t_lemma =~ m/^[^#]/ or $LEMMAS_TO_REMOVE->{ $child->t_lemma } ) ) {
            $self->_remove_node($child);
        }
    }

    $self->_processed->{$tnode} = 1;
    return;
}

# This prepares a node for deletion, arranging its children in various ways.
sub _remove_node {

    my ( $self, $to_remove ) = @_;

    # Modal verbs in aux.rf -> replace the node with them
    if ( $self->_handle_modal($to_remove) ) {
        return;
    }

    my @children = $to_remove->get_children( { ordered => 1 } );

    # no children -> simply remove and don't care anymore
    if ( @children == 0 ) {
        $self->_mark_for_removal($to_remove); # don't care for auxiliaries, too
        return;
    }

    # handle '#Separ' separately :-)
    if ( $to_remove->nodetype eq 'coap' ) {
        $self->_remove_coord($to_remove);
        return;
    }

    # merge duplicated coordination members
    if ( $self->_merge_coord_members($to_remove) ) {
        return;
    }

    # merge children, if there is more than one
    if ( @children > 1 ) {
        $self->_merge_children( $to_remove, $self->_find_most_important_child($to_remove) );
    }

    # replace the node with its child, determine the new functor
    $self->_remove_with_child($to_remove);

    return;
}

# This moves all orphaned a/aux.rf links from the node to another one and marks it for deletion
sub _mark_for_removal {

    my ( $self, $to_remove, $aux_backup ) = @_;
    my @anodes = $to_remove->get_aux_anodes();

    foreach my $anode (@anodes) {
        if ( @{ $self->_a_links->{$anode} } == 1 ) {
            if (!$aux_backup){
                log_warn('Losing some aux-rf: ' . $to_remove->id . ' and ' . $anode->id );
            }
            else {
                $aux_backup->add_aux_anodes($anode);
            }
        }
    }
    $self->_deleted->{$to_remove} = 1;
}

# This removes all nodes marked for deletion
sub _delete_marked {
    
    my ( $self, $troot ) = @_;
    my @nodes = $troot->get_descendants();
    foreach my $node (@nodes) {

        if ($self->_deleted->{$node}){
            $node->remove();
        }
    }
    return;
}

# This checks all coreference links within the tree, removing links to deleted nodes. 
sub _check_corefs {

    my ( $self, $troot ) = @_;
    my @nodes = $troot->get_descendants();

    foreach my $node (@nodes) {
        $node->update_coref_nodes();
    }
    return;
}


# This just collects a list of referencing nodes for each a-layer node
sub _gather_a_links {

    my ( $self, $troot ) = @_;
    my %links;

    my @tnodes = $troot->get_descendants();
    foreach my $tnode (@tnodes) {
        my @anodes = $tnode->get_anodes();
        foreach my $anode (@anodes) {
            if ( !$links{$anode} ) {
                $links{$anode} = [];
            }
            push @{ $links{$anode} }, $tnode;
        }
    }
    $self->_set_a_links( {%links} );
    return;
}

# If there is a node for which only the modal verb is expressed and the full verb elided, this
# moves the modal into the position of the full verb. Returns 1 if this is the case, 0 otherwise.
sub _handle_modal {

    my ( $self, $tnode ) = @_;

    # find a modal verb in aux.rf
    my ($modal) = grep { $self->_lexicon->is_modal_verb( $_->lemma ) } $tnode->get_aux_anodes();

    # if there is one, find out whether nothing else references it
    if ( $modal and @{ $self->_a_links->{$modal} } = 1 ) {

        # make the modal more important
        $tnode->remove_aux_anodes($modal);
        $tnode->set_lex_anode($modal);
        $tnode->set_t_lemma( $self->_lexicon->truncate_lemma( $modal->lemma ) );
        return 1;
    }

    return 0;
}

# This removes a coordination head node and rehangs all the coordination members to the parent of this node. Non-members
# of the coordination are rehanged to the nearest member child.
sub _remove_coord {

    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent();
    my @children = $tnode->get_children( { ordered => 1 } );

    # replace the fphr node type with normal nodes
    # TODO is this required ? is dphr sufficient ?
    for ( my $i = 0; $i < @children; ++$i ) {
        if ( $children[$i]->nodetype eq 'fphr' ) {
            $children[$i]->set_nodetype('dphr');
        }
    }
    
    # rehang the children
    for ( my $i = 0; $i < @children; ++$i ) {

        # hang members to parent
        if ( $children[$i]->is_member() ) {
            $children[$i]->set_parent($parent);
        }

        # non-members -- find nearest suitable member (skipping atomic nodes, since they can't have children)
        else {
            my $j = $i + 1;
            while ( $j < @children and ( !$children[$j]->is_member() or $children[$j]->nodetype eq 'atom' ) ) {
                $j++;
            }
            if ( $j >= @children ) {
                $j = $i - 1;
                while ( $j >= 0 and ( !$children[$j]->is_member() or $children[$j]->nodetype eq 'atom' ) ) {
                    $j--;
                }
            }
            $children[$i]->set_parent( $children[$j] );
        }        
    }

    # remove the node itself (shouldn't have any aux.rf)
    $self->_mark_for_removal($tnode);
    return;
}

# Merges duplicated coordination members, if there are some, and returns 1. Returns 0 otherwise.
sub _merge_coord_members {

    my ( $self, $tnode ) = @_;

    my @siblings = grep { $_->is_member } $tnode->get_siblings();
    my @non_gen  = grep { !$_->is_generated } @siblings;

    # Need to process subtrees of all siblings first (will return if already done)
    foreach my $sibling (@siblings) {
        $self->_process_subtree($sibling);
    }

    # there is one non-generated member and all the other members share the same functor
    if (@non_gen == 1
        and ( grep { $_->t_lemma eq $tnode->t_lemma and $_->functor eq $tnode->functor } @siblings ) == scalar(@siblings)
        )
    {

        # find out if all of the coordinated siblings have a child with the same functor
        foreach my $child ( $tnode->get_children ) {

            my $same_functor = 1;

            foreach my $sibling (@siblings) {
                if ( !grep { $_->functor eq $child->functor } $sibling->get_children() ) {
                    $same_functor = 0;
                    last;
                }
            }

            # children with the same functor found -> rehang the whole coordination
            if ($same_functor) {

                $non_gen[0]->set_parent( $tnode->get_parent()->get_parent() );
                $non_gen[0]->set_is_member(undef);
                $tnode->get_parent->set_parent( $non_gen[0] );

                foreach my $sibling ( @siblings, $tnode ) {

                    my ($coord_child) = grep { $_->functor eq $child->functor } $sibling->get_children();
                    $coord_child->set_parent( $tnode->get_parent() );
                    $coord_child->set_is_member(1);

                    if ( $sibling != $non_gen[0] ) {
                        $self->_merge_children( $sibling, $coord_child );
                        $self->_mark_for_removal( $sibling, $coord_child );
                    }
                }

                return 1;
            }
        }
    }
    return 0;
}

# Merge all the children of a given node under one of its children.
sub _merge_children {

    my ( $self, $tnode, $under ) = @_;
    my @children = grep { $_ != $under } $tnode->get_children();

    foreach my $child (@children) {
        $child->set_parent($under);
    }
    return;
}

# This removes from the tree a node which has just one child. If the functor of the removed
# node has a greater position in the FUNCTORS_HIERARCHY, its functor is kept instead of the child one
sub _remove_with_child {

    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent();
    my ($child) = $tnode->get_children();

    if ( $FUNCTORS_HIERARCHY->{ $child->functor } < $FUNCTORS_HIERARCHY->{ $tnode->functor } ) {
        $child->set_functor( $tnode->functor );
    }
    $child->set_parent($parent);
    $self->_mark_for_removal( $tnode, $child );
    return;
}

# Find the most important child in terms of functors priority (see $FUNCTORS_PRIORITY) and
# order (later is more important)
sub _find_most_important_child {

    # TODO remove atomic
    my ( $self, $tnode ) = @_;
    my @children       = $tnode->get_children();
    my $most_important = $children[0];

    for my $child (@children) {
        if ( $FUNCTORS_PRIORITY->{ $child->functor } >= $FUNCTORS_PRIORITY->{ $most_important->functor } ) {
            $most_important = $child;
        }
    }
    return $most_important;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::DeleteGeneratedNodes

=head1 DESCRIPTION

This block deletes all generated nodes from the PDT/PEDT sentence representation that are not used in the 
current Treex/TectoMT analyses (i.e. elided words / obligatory actors etc.). 

=head2 ALGORITHM

The deletion rules are as follows:

=over

=item 1.

A check for modal verbs in C<aux.rf> is made. If there should be a modal verb along with the deleted node,
the node is converted to non-generated with the modal as a full verb. 

=item 2.

If the node has no children, it is deleted. Any loose C<aux.rf> members are hanged to its parent.

=item 3.

Generated duplicated coordination members are merged if there is one non-generated member and if all of them have the 
same functor and at least one child with the same functor. The coordination is then passed on to the children sharing the 
same functor. 

Any other children of the generated members are hanged under the newly coordinated children.
Any loose C<aux.rf> members are hanged to the newly coordinated children.

=item 4.

If the node has just one child, it is replaced by this child, passing all now loose C<aux.rf> members on to it.
The C<FUNCTOR_HIERARCHY> is applied to determine which of the functors (deleted parent or child) is kept as the new
functor of the resulting node. Any now loose C<aux.rf> members are hanged to the resulting node.

=item 5.

If the node has more than one child, the C<FUNCTOR_PRIORITY>, C<sempos> (verbs > nouns > adjectives > adverbs), C<nodetype> and
order is used to determine which one of the children is the "most important". All the other children of the node
are hanged under the "most important" one and the previous case is applied.

=back

=head1 TODO

The C<FUNCTOR_PRIORITY> and C<FUNCTOR_HIERARCHY> should require more testing.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
