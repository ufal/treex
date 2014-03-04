package Treex::Block::A2T::SK::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkEdgesToCollapse';

has quotes => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    documentation => 'mark quotation marks as auxiliary?',
);

has expletives => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'mark expletives (e.g. "v *tom*, že") as auxiliary?',
);


override tnode_although_aux => sub {
    my ( $self, $node ) = @_;

    # AuxY and AuxZ are usually used for rhematizers (which should have their own t-nodes).
    return 1 if $node->afun =~ /^Aux[YZ]/;

    # AuxG = graphic symbols (dot not serving as terminal punct, colon etc.)
    # These are quite hard to translate unless left as t-nodes.
    # Round brackets are excepted from this rule.
    return 1 if $node->afun eq 'AuxG' && $node->form !~ /^[()]$/;

    # The current translation expects quotes as self-standing t-nodes.
    return 1 if !$self->quotes && $node->form =~ /^(''|``|[„“"])$/;
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
        && any { $_->lemma eq 'byť' && $_->tag =~ m/^Vf/ } $infinitive->get_echildren( { or_topological => 1 } )
        );

    return 0;
}

# Return 1 if $modal is a modal verb with regards to its $infinitive child
override is_modal => sub {
    my ( $self, $modal, $infinitive ) = @_;
    
    # state passive "je(lemma=být) připraven(parent=je,tag=Vs,afun=Pnom)"
    # This is definitely not a modal construction,
    # but technicaly it's easiest to solve it here.
    return 1 if $infinitive->tag =~ /^Vs/ && $modal->lemma eq 'byť';

    # Check if $infinitive is the lexical verb with which the modal should merge.
    return 0 if !$self->_is_infinitive( $modal, $infinitive );

    # "Standard" modals
    return 1 if $modal->lemma =~ /^(musieť|mať|chcieť|hodlať|môcť|vedieť|smieť)(\_.*)?$/;

    # "Semi-modals"
    # (mostly) modal 'dát se'
    return 1 if ( $modal->lemma eq 'dať' && grep { $_->form eq 'sa' } $modal->get_children() );

    return 0;
};


override is_aux_to_parent => sub {
    my ( $self, $node ) = @_;

    # Reuse base-class language independent rules
    my $base_result = super();
    return $base_result if defined $base_result;

    # ???
    my $parent = $node->get_parent();
    return 1 if lc( $parent->form ) eq 'ako' && $parent->afun eq 'AuxY';

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
    return 1 if $self->expletives && $node->form =~ /^(že|aby)$/ && $parent->lemma eq 'ten' && $parent->tag =~ /^PD[ZNH]S.*/;
    return 0;
};

1;


