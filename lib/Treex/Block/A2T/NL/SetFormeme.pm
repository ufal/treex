package Treex::Block::A2T::NL::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::EN::SetFormeme';

override 'detect_syntpos' => sub {

    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();

    # coap nodes must have empty syntpos
    return '' if ( $t_node->nodetype ne 'complex' ) && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;

    # let's assume generated nodes are (pro)nouns
    return 'n' if ( !$a_node );

    my $tag = $a_node->tag;

    # adjective-like pronouns and numerals
    return 'adj' if ( $a_node->match_iset( 'prontype' => '~(dem|rel|int|ind)', 'synpos' => 'attr' ) );
    return 'adj' if ( $a_node->is_numeral and $a_node->match_iset( 'synpos' => 'attr' ) );

    # nouns, adjectives in predicative and substantival positions
    return 'n' if ( $a_node->is_noun );
    return 'n' if ( $a_node->match_iset( 'pos' => 'verb', 'synpos' => 'subst' ) );
    return 'n' if ( $a_node->match_iset( 'pos' => 'adj', 'synpos' => '~(subst|pred)' ) );

    # verbs (including attributive)
    return 'v' if ( $a_node->is_verb );

    # attributive adjectives
    return 'adj' if ( $a_node->is_adjective or $a_node->match_iset( 'synpos' => 'attr' ) );

    # adverbs, adverbial adjectives
    return 'adv' if ( $a_node->is_adverb or $a_node->match_iset( 'synpos' => 'adv' ) );

    # default to noun
    return 'n';
};

# semantic nouns
override '_noun' => sub {

    my ( $self, $t_node, $a_node ) = @_;
    return 'n:poss' if $a_node->match_iset( 'poss' => 'poss' );

    # TODO: Postpositons are not handled
    my $prep = $self->get_aux_string( $t_node->get_aux_anodes( { ordered => 1 } ) );
    return "n:$prep+X" if $prep;

    if ( $self->below_verb($t_node) ) {

        my $afun = $a_node->afun;

        # TODO: same as English, should fix afuns though
        return 'n:adv'  if $afun eq 'Adv';
        return 'n:subj' if $afun eq 'Sb';

        # word-order guesses wouldn't work, afuns use them anyway in the P2A::NL::Alpino block
        return 'n:obj';
    }
    if ( $self->below_noun($t_node) or $self->below_adj($t_node) ) {
        return 'n:poss' if $a_node->match_iset( 'case' => 'genitive' );
        return 'n:attr';
    }

    # same default as in English
    return 'n:';
};

# semantic adjectives
override '_adj' => sub {
    my ( $self, $t_node, $a_node ) = @_;

    my $prep = $self->get_aux_string( $t_node->get_aux_anodes( { ordered => 1 } ) );
    my $afun = $a_node->afun;

    return "n:$prep+X" if $prep;                                                     # adjectives with prepositions are treated as a nominal usage
    return 'adj:attr'  if $self->below_noun($t_node) || $self->below_adj($t_node);
    return 'n:subj'    if $afun eq 'Sb';                                             # adjectives in the subject positions -- nominal usage
    return 'adj:compl' if $self->below_verb($t_node);

    return 'adj:';
};

# semantic verbs
override '_verb' => sub {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my $first_verbform = ( first { $_->is_verb && !$self->is_prep_or_conj($_) } $t_node->get_anodes( { ordered => 1 } ) ) || $a_node;

    my $subconj = $self->get_subconj_string( $first_verbform, @aux_a_nodes );

    if ( $first_verbform->match_iset( 'verbform' => 'inf' ) ) {
        return "v:$subconj+inf" if ($subconj);
        return 'v:inf';
    }

    if ( $first_verbform->match_iset( 'verbform' => 'part', 'tense' => 'pres' ) ) {
        return "v:$subconj+ger" if $subconj;
        return 'v:attr' if $self->below_noun($t_node);
        return 'v:ger';
    }

    if ( $t_node->is_clause_head ) {
        return "v:$subconj+fin" if $subconj;
        return 'v:rc' if $t_node->is_relclause_head;
        return 'v:fin';
    }

    if ( $first_verbform->match_iset( 'verbform' => 'part', 'tense' => 'past' ) ) {
        return "v:$subconj+fin" if $subconj;
        return 'v:attr';
    }

    # default to finite forms
    return "v:$subconj+fin" if $subconj;
    return 'v:fin';
};

override 'is_prep_or_conj' => sub {
    my ( $self, $a_node ) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;

    # If afun is not reliable, try also tag (but avoid separable verbal prefixes)
    return 1 if ( $a_node->is_preposition or $a_node->is_conjunction ) and ( $a_node->afun ne 'AuxV' );

    return 0;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::NL::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of Dutch t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

TODO: This is based on the English block. Possibly create an independent base class?

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
