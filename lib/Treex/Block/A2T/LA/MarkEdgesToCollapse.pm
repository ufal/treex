package Treex::Block::A2T::LA::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';

# Return 1 if $modal is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $modal, $infinitive ) = @_;
    
    return 0 if $infinitive->tag !~ /^3..[HQ]/;
    if ($infinitive->afun eq 'Sb'){

        # "necesse(parent=est) est(lemma=sum) facere(infinitive, parent=est)"
        if ($modal->lemma eq 'sum'){
            my $necesse = first {$_->lemma eq 'necesse'} $infinitive->get_siblings;
            return 0 if !$necesse;
            $necesse->set_edge_to_collapse(1);
            $necesse->set_is_auxiliary(1);
            return 1;
        }
        return 1 if $modal->lemma eq 'oportet';
        return 0;
    }
    return 1 if $modal->lemma =~ /^(possum|debeo|volo|nolo|malo|soleo|intendo)$/;
    return 0;
};

override tnode_although_aux => sub {
    my ( $self, $node ) = @_;
    
    # multiple conjunctions in a coordination should be collapsed
    return 0 if $node->afun eq 'AuxY' && $node->lemma =~ /^(et|sive|vel|aut|neque|nec)$/ && $node->get_parent->afun eq 'Coord';
    
    # AuxY(expecpt from the rule above) and AuxZ are usually used for rhematizers (which should have their own t-nodes).
    return 1 if $node->afun =~ /^Aux[YZ]/;
    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::MarkEdgesToCollapse

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for Latin
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Marco Passarotti

=head1 COPYRIGHT AND LICENSE

Copyright © 2012,2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
