package Treex::Block::A2T::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $node ) = @_;

    # default values
    $node->set_edge_to_collapse(0);
    $node->set_is_auxiliary(0);

    # Bottom-up recursive DFS traversal
    foreach my $child ( $node->get_children() ) {
        $self->process_atree($child);
    }

    # The technical root cannot be collapsed to parent (nor parent to it)
    return if $node->is_root();
    my $parent = $node->get_parent();

    # Check multi-lex.rf going to one t-node
    my @lex_adepts =
        grep { $_->edge_to_collapse && $_->wild->{lex_adepts} }
        $node->get_children( { ordered => 1 } );
    $node->wild->{lex_adepts} = scalar @lex_adepts;
    if ( @lex_adepts > 1 ) {
        $self->solve_multi_lex( $node, @lex_adepts );
    }

    # No node (except AuxK = terminal punctuation: ".?!")
    # can collapse to the technical root.
    if ( $parent->is_root() ) {
        if ( $node->afun eq 'AuxK' ) {
            $node->set_edge_to_collapse(1);
            $node->set_is_auxiliary(1);
        }
    }

    # Should collapse to parent because the $node is auxiliary?
    elsif ( $self->is_aux_to_parent($node) ) {
        $node->set_edge_to_collapse(1);
        $node->set_is_auxiliary(1);
    }

    # Should collapse to parent because the $parent is auxiliary?
    elsif ( $self->is_parent_aux_to_me($node) ) {
        $node->set_edge_to_collapse(1);
        $parent->set_is_auxiliary(1);

        # If $node is not auxiliary, it is itself a lexical adept.
        if ( !$node->is_auxiliary ) {
            $node->wild->{lex_adepts}++;
        }
    }

    return;
}

sub is_aux_to_parent {
    my ( $self, $node ) = @_;

    # Rhematizers (Aux[YZ]) should have their own t-nodes.
    # Also, overriden classes may want e.g. quotation marks to be represented
    # by a t-node although the a-node has afun=AuxG.
    return 0 if $self->tnode_although_aux($node);

    # Auxiliary nodes should collapse either to parent or to a child.
    # The latter case means that $node is already marked as auxiliary
    # (by is_parent_aux_to_me called on some of its children).
    # So all remaining aux nodes will be marked to collapse to parent.
    return 1 if !$node->is_auxiliary && $node->afun =~ /^Aux/;

    return undef;
}

sub is_parent_aux_to_me {
    my ( $self, $node ) = @_;
    
    # Overriden classes may want e.g. some prepositions ("than") or modals
    # to be represented by a t-node. Also, the root cannot collapse to parent.
    my $parent = $node->get_parent();
    return 0 if !$parent || $self->tnode_although_aux($parent);

    # AuxP = preposition, AuxC = subord. conjunction
    # Aux[CP] node usually has just one child (noun under AuxP, verb under AuxC).
    # The lower nodes of multiword Aux[CP] (Aux[CP] under Aux[CP])
    # are marked already by the method is_aux_to_parent (which is checked first).
    # If Aux[CP] node has two or more non-aux children, we mark all of them here,
    # but solve_multi_lex is executed afterwards and it should choose just one.
    return 1 if $parent->afun =~ /Aux[CP]/;

    # modal verbs (including coordinated lexical verbs sharing one modal verb)
    # If $node->is_coap_root then $_ are the possible lexical verbs (conjuncts).
    # Otherwise, $node->get_coap_members() == ($node) == ($_).
    return 1 if any { $self->is_modal( $parent, $_ ) } $node->get_coap_members();

    return undef;
}

sub tnode_although_aux {
    my ( $self, $node ) = @_;

    # AuxY and AuxZ are usually used for rhematizers (which should have their own t-nodes).
    return 1 if $node->afun =~ /^Aux[YZ]/;
    return 0;
}

sub solve_multi_lex {
    my ( $self, $node, @lex_adepts ) = @_;
    return;
}

# Return 1 if $node is a modal verb with regards to its $infinitive child
sub is_modal {
    my ( $self, $node, $infinitive ) = @_;

    # "To serve($infinitive,afun=Sb,parent=should) as subject inifinitive clause
    #  should not be considered being part of modal construction."
    return 0 if $infinitive->afun eq 'Sb';

    # Either use a block that fills Interset features, or override this method.
    return 1 if $node->match_iset('pos' => 'verb', 'subpos' => 'mod') && $infinitive->get_iset('pos') eq 'inf';

    return 0;
}

# helper method to be used from solve_multi_lex in derived classes
sub try_rule {
    my ( $self, $condition, $adepts_ref ) = @_;

    # Let @ok be the list of adepts for which the condition holds.
    my @ok = grep { $condition->($_) } @$adepts_ref;
    return 0 if !@ok;

    # If more than one adept found, substitute the original @lex_adepts for them.
    if ( @ok > 1 ) {
        @$adepts_ref = @ok;
        return 0;
    }

    # So there is just one "true" adept, and all other should not collapse to parent.
    # Note that @$adepts_ref may include only a subset of all original adepts,
    # so we need to check all siblings again.
    my $true_adept = $ok[0];
    my @false_adepts = grep { $_->edge_to_collapse && $_->wild->{lex_adepts} } $true_adept->get_siblings();
    foreach my $false_adept ( @false_adepts ) {
        $false_adept->set_edge_to_collapse(0);
    }
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::MarkEdgesToCollapse - prepare a-trees for building t-trees

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block is supposed to serve as a base class for language specific blocks.
It could be also used directly in scenarios as a baseline language independent block.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
