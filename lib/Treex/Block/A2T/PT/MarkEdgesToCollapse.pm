package Treex::Block::A2T::PT::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
use LX::Data::PT;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';


my $regexp = "^(".(join "|",@LX::Data::PT::ObliqueInherentVerbs).")\$";

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;


    # Superlative and comparative "mais"
    # We are interested in the (first) effective parent.
    # If our tree-parent is a coord, the $node will collapse to this conjunction
    # and afterwards it will be distributed as aux to all members of the coordination.
    # Otherwise, our tree-parent is the same as effective parent.
    if ( $node->lemma eq 'mais' ) {
        my ($eparent) = $node->get_eparents();
        return 0 if $eparent->is_root();
        return 1 if $eparent->is_adjective || $eparent->is_adverb;
    }

  
    my $a_parent = $node->parent;
    if($a_parent and $node->lemma eq 'se' and $a_parent->lemma =~  /$regexp/){
        return 1;

    }

    if($a_parent and $node->lemma eq 'não' and $a_parent->iset->pos eq "verb") {
        return 1;
    }

    return 0;
};


#TODO: treatment of modal verbs postponed

#override is_modal => sub {
#    my ( $self, $modal, $infinitive ) = @_;

    # Check if $infinitive is the lexical verb with which the modal should merge.
#    return 0 if !$self->_is_infinitive( $modal, $infinitive );
    
#    return 1 if $modal->lemma =~ /^(poder|querer|dever)$/;

#    return 0;
#};

#sub _is_infinitive {
#    my ( $self, $modal, $infinitive ) = @_;
#    return 1 if $infinitive->iset->verbform eq "inf";
#    return 0;
#}






1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::PT::MarkEdgesToCollapse - prepare a-trees for building t-trees

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for Portuguese
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
