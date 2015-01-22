package Treex::Block::A2T::NL::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';

has quotes => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'mark quotation marks as auxiliary?',
);

override tnode_although_aux => sub {
    my ( $self, $node ) = @_;

    # rhematizers are not marked as such yet, but this won't do any harm
    return 1 if $node->afun =~ /^Aux[YZ]/;

    # AuxG = graphic symbols (dot not serving as terminal punct, colon etc.)
    # These are quite hard to translate unless left as t-nodes.
    # Round brackets are excepted from this rule.
    return 1 if $node->afun eq 'AuxG' && $node->form !~ /[\(\)]/;

    # keep comparative prepositions, same as English
    return 1 if $node->lemma =~ /^(dan|als)$/
        && any { $_->afun eq 'AuxP' } $node->get_children();

    # The current translation expects quotes as self-standing t-nodes.
    return 1 if !$self->quotes && $node->form =~ /^["'`„“”‚‘’]+$/;
    return 0;
};

sub _is_infinitive {
    my ( $self, $modal, $infinitive ) = @_;

    # Infinitives cannot work as subjects
    return 0 if ( $infinitive->afun eq 'Sb' );

    # Infinitives cannot precede modals, unless they are shifted to the end of the clause
    # and precede the infinitive directly (but for an auxiliary verb)
    if ( $infinitive->precedes($modal) ) {
        my @between = $modal->get_nodes_between($infinitive);
        return 0 if ( @between > 1 or ( @between and $between[0]->afun ne 'AuxV' ) );
    }

    # $infinitive (or one of its descendants) must be an infinitive (same as in English)
    # Je moet gaan. Dit moet worden gedaan.
    return 1 if $infinitive->match_iset( 'verbform' => 'inf' );
    return 1 if $infinitive->match_iset( 'verbform' => 'part' )
        && any { $self->_is_infinitive( $modal, $_ ) }
    grep { $_->edge_to_collapse } $infinitive->get_children();

    return 0;
}

# Return 1 if $modal is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $modal, $infinitive ) = @_;

    # Check if $infinitive is the lexical verb with which the modal should merge.
    return 0 if !$self->_is_infinitive( $modal, $infinitive );

    # "Standard" modals
    return 1 if $modal->lemma =~ /^(kunnen|moeten|mogen|willen|zullen)$/;

    # TODO: verbs that behave the same but we don't have grammateme values
    # - gaan, blijven, komen +te (maybe more)
    # TODO: hoeven

    return 0;
};

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    # standalone (existential) "er"
    if ( lc $node->form eq 'er' ) {
        my ($eparent) = $node->get_eparents();
        return 1 if $eparent->is_verb();    # formal subject
        return 0;                           # eraan, ermee etc.
    }

    # Analytical comparative and superlative
    if ( lc( $node->form ) =~ /^(meer|meest)$/ ) {
        my ($eparent) = $node->get_eparents();
        return 0 if $eparent->is_root();
        return 1 && $eparent->is_adverb() or $eparent->is_conjunction();
    }

    return 0;
};

# Rules for solving multiple lexical nodes for a t-node
override solve_multi_lex => sub {
    my ( $self, $node, @adepts ) = @_;

    # Prepositions and subord. conjunctions
    if ( $node->afun =~ /Aux[CP]/ ) {

        # prepositions should precede 'their real' child
        return if $self->try_rule( sub { $node->precedes( $_[0] ) }, \@adepts );

        # For preps the 'real' child is a noun, and for conjs a verb or noun (see English)
        my $wanted_pos = $node->afun eq 'AuxP' ? 'noun' : '(verb|noun)';
        return if $self->try_rule( sub { $_[0]->match_iset( 'pos' => $wanted_pos ) }, \@adepts );

        # If no previous heuristic helped, choose the leftmost child.
        return if $self->try_rule( sub { $_[0] == $adepts[0] }, \@adepts );
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::NL::MarkEdgesToCollapse - prepare a-trees for building t-trees

=head1 DESCRIPTION

This block prepares a-trees for transformation into t-trees by filling in
two attributes: C<is_auxiliary> and C<edge_to_collapse>.
Each node marked as I<auxiliary> will not be present at the t-layer as a t-node.
It will collapse to its I<lexical> node according to C<edge_to_collapse>.
Generally, prepositions, subordinating conjunctions, and modal verbs
collapse to one of their children.
Other auxiliary nodes (aux verbs, determiners, commas,...) collapse to their parent.
Before applying this block, afun values must be filled (especially Aux* and Coord).

This block contains language specific rules for Dutch
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.
It is based on the analogous block for English, L<Treex::Block::A2T::NL::MarkEdgesToCollapse>. 

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
