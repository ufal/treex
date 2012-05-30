package Treex::Block::A2T::EN::MarkEdgesToCollapseNew;
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

    # AuxG = graphic symbols (dot not serving as terminal punct, colon etc.)
    # These are quite hard to translate unless left as t-nodes.
    # TODO: this leads to "Mr." being translated as "pan."
    # Round brackets are excepted from this rule.
    return 1 if $node->afun eq 'AuxG' && $node->tag !~ /-LRB-|-RRB-/;
    
    # "than" is a preposition but it can be combined with various other preps
    # e.g. "denser than on Earth" would result in formeme n:than_on+X.
    # For the current translation it is easier to treat such "than" as t-node. 
    return 1 if $node->lemma eq 'than' && any {$_->afun eq 'AuxP'} $node->get_children();

    # The current translation expects quotes as self-standing t-nodes.
    return 1 if !$self->quotes && $node->tag =~ /^(''|``)$/;
    return 0;
};

# Return 1 if $node is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $node, $infinitive ) = @_;

    # Check if
    # * $node is a modal verb
    # * $infinitive is the lexical verb with which the modal should merge
    #   Note that $infinitive does not need to be infinitive in sense tag=VB.
    #   "It could(tag=MD) be(tag=VB,parent=done) done(tag=VBN,parent=could)."
    # * "To serve(tag=VB,afun=Sb,parent=should) as subject infinitive clause
    #    should not be considered being part of modal construction."
    return
        $node->lemma =~ /^(can|cannot|must|may|might|should|would|could|shall)$/
        && $node->precedes($infinitive) && $infinitive->tag =~ /^V/
        && $infinitive->afun ne 'Sb';
};

override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    # RP  = adverb particle ("up, off, out,...")
    # EX  = existential "there"
    # POS = possessive "'s"
    return 1 if $node->tag =~ /^(RP|EX|POS|-NONE-)$/;

    # "More" and "most"
    # We are interested in the (first) effective parent.
    # If our tree-parent is a coord, the $node will collapse to this conjunction
    # and afterwards it will be distributed as aux to all members of the coordination.
    # Otherwise, our tree-parent is the same as effective parent.
    if ( $node->lemma =~ /^(more|most)$/ ) {
        my ($eparent) = $node->get_eparents();
        return 0 if $eparent->is_root();
        return 1 && $eparent->tag =~ /^(JJ|RB)/;
    }

    return 0;
};

override is_parent_aux_to_me => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    my $parent = $node->get_parent();
    my ( $tag, $lemma, $afun ) = $node->get_attrs(qw(tag lemma afun));
    my ( $p_tag, $p_form, $p_lemma, $p_afun ) = $parent->get_attrs(qw(tag form lemma afun));

    # want/have/ought/going to
    # 'want' added by ZZ (not stricly modal in the sense of English grammar, but modal in FGD)
    # "You have to(tag=TO, parent=go) go(parent=have)."
    if ( ( $p_lemma =~ /^(have|ought|want)/ || $p_form eq 'going' ) && $tag eq 'VB' ) {
        my $first_child = $node->get_children( { first_only => 1 } );
        return 1 if $first_child && $first_child->lemma eq 'to';
    }

    # 2d) be able to VB
    return 1 if $lemma eq 'able' && $p_lemma eq 'be';
    return 1 if $tag   eq 'VB'   && $p_lemma eq 'able';
    return 0;
};

override solve_multi_lex => sub {
    my ( $self, $node, @adepts ) = @_;

    # 1) Prepositions and subord. conjunctions
    if ( $node->afun =~ /Aux[CP]/ ) {

        # 1a) prepositions should precede 'their real' child
        return if $self->try_rule( sub { $node->precedes( $_[0] ) }, \@adepts );

        # 1b)
        # For preps the 'real' child is a noun, and for conjs a verb or noun.
        # "Particulary(tag=RB, parent=at) at(afun=AuxP) risk(tag=NN, parent=at)"
        # "... of(afun=AuxP) $(tag=$, parent=of) 10(parent=$) strange_word(parent=of)"
        # Why nouns for conjs? "In case of errors..." No matter whether you call
        # in_case_of a phrasal conjunction or conjunctional preposition.
        my $wanted_regex = $node->afun eq 'AuxP' ? 'NN|PRP|CD|\$' : 'V|PRP|NN|CD|\$';
        return if $self->try_rule( sub { $_[0]->tag =~ $wanted_regex }, \@adepts );

        # 1c) If no previous heuristic helped, choose the leftmost child.
        return if $self->try_rule( sub { $_[0] == $adepts[0] }, \@adepts );
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::MarkEdgesToCollapse - prepare a-trees for building t-trees

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
