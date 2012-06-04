package Treex::Block::A2T::GRC::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';


# Return 1 if $node is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $node, $infinitive ) = @_;

    # Check if $infinitive is the lexical verb with which the modal should merge.
    # Note that $infinitive does not need to be infinitive in sense tag=VB.
    # "It could(tag=MD) be(tag=VB,parent=done) done(tag=VBN,parent=could)."
    return 0 if $infinitive->precedes($node) || $infinitive->tag !~ /^V/;

    # "To serve(tag=VB,afun=Sb,parent=should) as subject infinitive clause
    #  should not be considered being part of modal construction."
    return 0 if $infinitive->afun eq 'Sb';

    # "Standard" modals
    # (no inflection -s in the 3rd pers, cannot form participles)
    # Note that "will" is marked as AuxV (and not considered a modal), so it is
    # under the main verb and it is marked as auxiliary in is_aux_to_parent.
    return 1 if $node->lemma =~ /^(can|cannot|could|may|might|must|shall|should|would)$/;

    # "Semi-modals"
    # (not stricly modal in the sense of English grammar, but expressing modality)
    # These take a long infinitive form with the particle "to".
    # "You have to(tag=TO, parent=go) go(parent=have)."
    if ( $node->lemma =~ /^(have|ought|want)$/ || lc( $node->form ) eq 'going' ) {
        my $first_child = $infinitive->get_children( { first_only => 1 } );
        return 1 if $first_child && $first_child->lemma eq 'to';
    }

    # "be able to VB" (border-case semi-modal)
    # multi word, so both the edges must be collapsed to parent
    return 1 if $node->lemma eq 'be'   && $infinitive->lemma eq 'able';
    return 1 if $node->lemma eq 'able' && $infinitive->tag   eq 'VB';

    return 0;
};

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    # TODO: mark cases when a node does not have afun=Aux*,
    # but still should collapse to parent.
    # This is language specific, e.g. in English:
    # RP  = adverb particle ("up, off, out,...")
    # EX  = existential "there"
    # POS = possessive "'s"
    #return 1 if $node->tag =~ /^(RP|EX|POS)$/;

    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::GRC::MarkEdgesToCollapse

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for English
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
