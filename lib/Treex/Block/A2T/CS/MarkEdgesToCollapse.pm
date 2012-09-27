package Treex::Block::A2T::CS::MarkEdgesToCollapse;
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
    # Round brackets are excepted from this rule.
    return 1 if $node->afun eq 'AuxG' && $node->form !~ /^[()]$/;

    # The current translation expects quotes as self-standing t-nodes.
    return 1 if !$self->quotes && $node->tag =~ /^(''|``|[„“"])$/;
    return 0;
};

sub _is_infinitive {
    my ( $self, $modal, $infinitive ) = @_;

    # active voice 'dělat'
    return 1 if $infinitive->tag =~ /^Vf/;

    # passive voice 'být dělán'
    return 1
        if (
        $infinitive->tag =~ /^Vs/
        && any { $_->lemma eq 'být' && $_->tag =~ m/^Vf/ } $infinitive->get_echildren( { or_topological => 1 } )
        );

    return 0;
}

# Return 1 if $modal is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $modal, $infinitive ) = @_;
    
    # state passive "je(lemma=být) připraven(parent=je,tag=Vs,afun=Pnom)"
    # This is definitely not a modal construction,
    # but technicaly it's easiest to solve it here.
    return 1 if $infinitive->tag =~ /^Vs/ && $modal->lemma eq 'být';

    # Check if $infinitive is the lexical verb with which the modal should merge.
    return 0 if !$self->_is_infinitive( $modal, $infinitive );

    # "Standard" modals
    return 1 if $modal->lemma =~ /^(muset|mít|chtít|hodlat|moci|dovést|umět|smět)(\_.*)?$/;

    # "Semi-modals"
    # (mostly) modal 'dát se'
    return 1 if ( $modal->lemma eq 'dát' && grep { $_->form eq 'se' } $modal->get_children() );

    return 0;
};


override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    # ???
    my $parent = $node->get_parent();
    return 1 if lc( $parent->form ) eq 'jako' && $parent->afun eq 'AuxY';

    return 0;
};

override solve_multi_lex => sub {
    my ( $self, $node, @adepts ) = @_;

    # Prepositions and subord. conjunctions
    if ( $node->afun =~ /Aux[CP]/ ) {

        # prepositions should precede 'their real' child
        return if $self->try_rule( sub { $node->precedes( $_[0] ) }, \@adepts );

        # For preps the 'real' child is a noun, and for conjs a verb or TODO: noun.
        # Why nouns for conjs? "víc než auto"
        my $wanted_regex = $node->afun eq 'AuxP' ? '^[NPC]' : '^V';
        return if $self->try_rule( sub { $_[0]->tag =~ $wanted_regex }, \@adepts );

        # If no previous heuristic helped, choose the leftmost child.
        return if $self->try_rule( sub { $_[0] == $adepts[0] }, \@adepts );
    }

    return;
};

override is_parent_aux_to_me => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;
    
    # collapse expletive 'to' above the conjunction 'že'/'aby'
    my $parent = $node->get_parent();   
    return 1 if ($node->form =~ /^(že|aby)$/ and $parent->lemma eq 'ten' and $parent->tag =~ /^PD[ZNH]S.*/);
    return 0;
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

This block contains language specific rules for Czech
and it is derived from L<Treex::Block::A2T::MarkEdgesToCollapse>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
