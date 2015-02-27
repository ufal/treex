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

    return 0;
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
