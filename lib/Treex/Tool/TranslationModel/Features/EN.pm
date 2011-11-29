package Treex::Tool::TranslationModel::Features::EN;
use strict;
use warnings;

sub _node_and_parent {
    my ( $tnode, $prefix ) = @_;

    # features from the given tnode
    my %feats = (
        lemma     => $tnode->t_lemma,
        formeme   => $tnode->formeme,
        voice     => $tnode->voice,
        negation  => $tnode->gram_negation,
        tense     => $tnode->gram_tense,
        number    => $tnode->gram_number,
        person    => $tnode->gram_person,
        degcmp    => $tnode->gram_degcmp,
        sempos    => $tnode->gram_sempos,
        is_member => $tnode->is_member,
    );
    my $short_sempos = $tnode->gram_sempos;
    if ( defined $short_sempos ) {
        $short_sempos =~ s/\..+//;
        $feats{short_sempos} = $short_sempos;
    }

    # features from tnode's parent
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
    if ( !$tparent->is_root ) {
        $feats{precedes_parent} = $tnode->precedes($tparent);
    }

    # features from a-layer
    my $anode = $tnode->get_lex_anode;
    if ($anode) {
        $feats{tag} = $anode->tag;
        $feats{capitalized} = 1 if $anode->form =~ /^\p{IsUpper}/;
    }

    # features from n-layer (named entity type)
    if ( my $n_node = $tnode->get_n_node() ) {
        $feats{ne_type} = $n_node->ne_type;
    }

    my %f;
    while ( my ( $key, $value ) = each %feats ) {
        if ( defined $value ) {
            $f{ $prefix . $key } = $value;
        }
    }
    return %f;
}

sub _child {
    my ( $tnode, $prefix ) = @_;
    my %feats = (
        lemma   => $tnode->t_lemma,
        formeme => $tnode->formeme,
    );

    my %f;
    while ( my ( $key, $value ) = each %feats ) {
        if ( defined $value ) {
            $f{ $prefix . $key . '_' . $value } = 1;
        }
    }
    return %f;
}

sub _prev_and_next {
    my ( $tnode, $prefix ) = @_;
    if ( !defined $tnode ) {
        return ( $prefix . 'lemma' => '_SENT_' );
    }
    return ( $prefix . 'lemma' => $tnode->t_lemma, );

}

sub features_from_src_tnode {
    my ($node) = @_;
    my ($parent) = $node->get_eparents( { or_topological => 1 } );

    my %features = (
        _node_and_parent( $node,   '' ),
        _node_and_parent( $parent, 'parent_' ),
        _prev_and_next( $node->get_prev_node, 'prev_' ),
        _prev_and_next( $node->get_next_node, 'next_' ),
        ( map { _child( $_, 'child_' ) } $node->get_echildren( { or_topological => 1 } ) ),
    );

    if ( $node->get_children( { preceding_only => 1 } ) ) {
        $features{has_left_child} = 1;
    }

    if ( $node->get_children( { following_only => 1 } ) ) {
        $features{has_right_child} = 1;
    }

    # We don't have a grammateme gram/definiteness so far, so let's hack it
    AUX:
    foreach my $aux ( $node->get_aux_anodes ) {
        my $form = lc( $aux->form );
        if ( $form eq 'the' ) {
            $features{determiner} = 'the';
            last AUX;
        }
        elsif ( $form =~ /^an?$/ ) {
            $features{determiner} = 'a';
        }
    }

    return \%features;
}

1;
