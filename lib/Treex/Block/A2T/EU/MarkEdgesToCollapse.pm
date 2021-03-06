package Treex::Block::A2T::EU::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';


override tnode_although_aux => sub {
    my ( $self, $node ) = @_;
    
    # Questionmark '¿' has afun=AuxG, but we want to hide it on t-layer,
    # i.e. make it an exception from the following rule
    return 0 if $node->lemma eq '¿' || $node->lemma eq '?';

    # AuxY and AuxZ are usually used for rhematizers (which should have their own t-nodes).
    # AuxG = graphic symbols (dot not serving as terminal punct, colon etc.)
    # These are quite hard to translate unless left as t-nodes.
    # Paired round brackets, parentheses and question marks will be solved later.
    return 1 if $node->afun =~ /^Aux[YZG]/;
    return 0;
};

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;


    # Negation
    if ( $node->lemma eq 'ez' ) {
        my ($eparent) = $node->get_eparents();
	if (!$eparent->is_root && ($eparent->is_verb || $eparent->is_adjective || $eparent->is_adverb)) {
	    $eparent->iset->set_negativeness('neg');
	    return 1;
	}
        
        # If the negative particle is not collapsed, it will become a t-node
        # and it should not have gram/negation=neg1 to prevent doubling the particle in synthesis.
        # So let's delete also the Interset negativeness feature.
        $node->iset->set_negativeness('');
        return 0;
    }


    # Questions
    if ($node->lemma eq 'al' || $node->lemma eq 'ba') {
	my ($eparent) = $node->get_eparents();
	if (!$eparent->is_root && ($eparent->is_verb)) {
	    return 1;
	}
    }

    return 0;
};

override is_parent_aux_to_me => sub {
    my ( $self, $node ) = @_;
    
    my $parent = $node->get_parent();
    return 0 if !$parent || $parent->is_auxiliary == 1 || $self->tnode_although_aux($parent);

    return 1 if ($node->is_verb() && $node->iset->verbform eq "" 
		 && $parent->lemma =~ /^(izan|ukan)$/);

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
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EU::MarkEdgesToCollapse - prepare a-trees for building t-trees

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for Basque
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Gorka Labaka <gorka.labaka@ehu.es>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
