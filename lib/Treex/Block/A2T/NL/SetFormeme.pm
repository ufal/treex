package Treex::Block::A2T::NL::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetFormeme';

use Treex::Tool::Lexicon::NL::VerbformOrder qw(normalized_verbforms);

override 'detect_syntpos' => sub {

    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();

    # coap nodes must have empty syntpos
    return 'x' if ( $t_node->nodetype ne 'complex' ) && ( $t_node->t_lemma || '' ) !~ m/^(%|°|#(Percnt|Deg))/;

    # let's assume generated nodes are (pro)nouns
    return 'n' if ( !$a_node );

    my $tag = $a_node->tag;

    # possessives, adjectives in predicative and substantival positions
    return 'n' if ( $a_node->match_iset( 'poss' => 'poss' ) );
    return 'n' if ( $a_node->match_iset( 'pos'  => 'adj', 'position' => 'nom' ) );
    return 'n' if ( $a_node->match_iset( 'pos'  => 'adj', 'position' => 'free' ) and $a_node->afun =~ /^(Pnom|Obj)$/ );

    # adverbial usage of adjectives
    return 'adv' if ( $a_node->match_iset( 'pos' => 'adj', 'position' => 'free' ) );

    # other adjectives, adjective-like pronouns and numerals
    return 'adj' if ( $a_node->is_adjective );
    return 'adj' if ( $a_node->match_iset( 'pos' => 'num', 'position' => 'prenom' ) );

    # nouns, nominal pronoouns and numerals
    return 'n' if ( $a_node->is_noun );

    # verbs (including attributive)
    return 'v' if ( $a_node->is_verb );

    # adverbs, adverbial pronouns pronouns
    return 'adv' if ( $a_node->is_adverb );

    # coordinating conjunctions (to be given the functor PREC), subordinating conjunctions "dan", "als"
    # "ja", "nee" as tags
    return 'x' if ( $a_node->is_conjunction || $a_node->is_interjection );

    # punctuation if kept on t-layer (quotation marks)
    return 'x' if ( $a_node->is_punctuation );

    # default to noun
    return 'n';
};

# semantic nouns
override 'formeme_for_noun' => sub {

    my ( $self, $t_node, $a_node ) = @_;
    return 'n:poss' if $a_node->match_iset( 'poss' => 'poss' );

    # TODO: Postpositons are not handled
    my $prep = $self->get_aux_string( $t_node->get_aux_anodes( { ordered => 1 } ) );
    return "n:$prep+X" if $prep;

    if ( $self->below_verb($t_node) ) {

        my $afun = $a_node->afun;

        return 'n:adv'   if $afun eq 'Adv';
        return 'n:subj'  if $afun eq 'Sb';
        return 'n:predc' if $afun eq 'Pnom';
        return 'n:obj2'  if ( ( $a_node->conll_deprel // '' ) eq 'obj2' );
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
override 'formeme_for_adj' => sub {
    my ( $self, $t_node, $a_node ) = @_;

    my $prep = $self->get_aux_string( $t_node->get_aux_anodes( { ordered => 1 } ) );
    my $afun = $a_node->afun;

    # adjectives with prepositions are treated as a nominal usage
    return "n:$prep+X" if $prep;

    return 'adj:attr' if $self->below_noun($t_node) || $self->below_adj($t_node);

    # adjectives in the subject/predicative positions -- nominal usage
    return 'n:subj'  if $afun eq 'Sb';
    return 'n:predc' if $afun eq 'Pnom';

    if ( $self->below_verb($t_node) ) {

        # adjectives used as adverbs: "hij rent snel(adj)" = "he runs quickly(adv)"
        return 'adv' if ( $afun eq 'Adv' or ( $a_node->match_iset( 'position' => 'free' ) and $afun ne 'Obj' ) );

        return 'adj:compl';
    }

    return 'adj:';
};

# semantic verbs
override 'formeme_for_verb' => sub {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my @verbforms = grep { !$self->is_prep_or_conj($_) } Treex::Tool::Lexicon::NL::VerbformOrder::normalized_verbforms($t_node);
    push @verbforms, $a_node if ( !@verbforms );
    my ($first_verbform) = @verbforms;
    my ($top_verbform) = sort { $a->get_depth <=> $b->get_depth } @verbforms;

    my $subconj = $self->get_subconj_string( $first_verbform, @aux_a_nodes );
    my $afun = '';

    if ( $self->below_verb($t_node) ) {
        $afun = ':subj'  if ( $top_verbform->afun eq 'Sb' );
        $afun = ':predc' if ( $top_verbform->afun eq 'Pnom' );
        $afun = ':obj'   if ( $top_verbform->afun eq 'Obj' );
    }

    if ( $first_verbform->match_iset( 'verbform' => 'inf' ) ) {
        return "v$afun:$subconj+inf" if ($subconj);
        return "v$afun:inf";
    }

    if ( $first_verbform->match_iset( 'verbform' => 'part', 'tense' => 'pres' ) ) {
        return "v$afun:$subconj+ger" if $subconj;
        return 'v:attr'              if $self->below_noun($t_node);
        return 'n:predc'             if $afun eq ':predc';
        return "v$afun:ger";
    }

    if ( $t_node->is_clause_head ) {
        return "v$afun:$subconj+fin" if $subconj;
        if ( $t_node->is_relclause_head ) {
            my ($tpar) = $t_node->get_eparents( { or_topological => 1 } );
            if ( !$tpar->is_root ) {
                return $top_verbform->afun eq 'Atr' ? 'v:rc' : 'v:indq';
            }
        }
        return "v$afun:fin";
    }

    if ( $first_verbform->match_iset( 'verbform' => 'part', 'tense' => 'past' ) ) {
        return "v$afun:$subconj+fin" if $subconj;
        return 'n:predc' if $afun eq ':predc';
        return "v$afun:attr";
    }

    # default to finite forms
    return "v$afun:$subconj+fin" if $subconj;
    return "v$afun:fin";
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

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
