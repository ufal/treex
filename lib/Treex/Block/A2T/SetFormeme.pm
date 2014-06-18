package Treex::Block::A2T::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;
    my @nodes = $t_root->get_descendants();

    # Fill formemes
    foreach my $t_node (@nodes) {
        my $formeme = $self->detect_formeme($t_node);
        $t_node->set_formeme($formeme);
    }

    return;
}

my %INTERSET_TO_SYNTPOS = (
    # synpos values:
    subst => 'n',
    attr  => 'adj',
    adv   => 'adv',
    pred  => 'adj', # predicative adjective

    # pos values:
    noun => 'n',
    adj  => 'adj',
    adv  => 'adv',
    verb => 'verb',
);

sub detect_syntpos {
    my ( $self, $t_node ) = @_;

    # Coordinators ("coap" nodes), rhematizers etc.
    return 'x' if $t_node->nodetype ne 'complex' && $t_node->t_lemma !~ m/^(%|°|#(Percnt|Deg))/;

    # Let's assume generated nodes are (pro)nouns.
    my $a_node = $t_node->get_lex_anode();
    return 'n' if !$a_node;

    # First, try Interset feature "synpos" (which should be filled for numerals).
    my $syntpos = $INTERSET_TO_SYNTPOS{$a_node->get_iset('synpos') || ''};
    return $syntpos if $syntpos;

    # Second, check for ordinal numerals (e.g. first, první, poprvé).
    # Sometimes, these can be syntactic advebs (poprvé=first_time), but usualy they are syntactic adjectives.
    # Ideally, they should have synpos=attr, so they are handled by the rule above, but let's make this robust.
    return 'adj' if $a_node->match_iset( 'pos' => 'num', numtype => 'ord' );

    # Third, try Interset feature "pos".
    $syntpos = $INTERSET_TO_SYNTPOS{$a_node->get_iset('pos') || ''};
    return $syntpos if $syntpos;

    # Fallback to noun.
    return 'n';
}

sub detect_formeme {
    my ($self, $t_node) = @_;
    my $syntpos = $self->detect_syntpos($t_node);

    # Non-complex type nodes (coordinations, rhematizers etc.)
    # have special formeme value instead of undef,
    # so tedious undef checking (||'') is no more needed.
    return 'x' if $syntpos eq 'x';

    # Punctuation in most cases should not remain on t-layer, but anyway
    # it makes no sense detecting formemes. (These are not unrecognized ???.)
    return 'x' if $t_node->t_lemma =~ /^([.;:-]|''|``)$/;

    # Choose the appropriate (possibly overriden) method according to the syntpos.
    my $a_node = $t_node->get_lex_anode();
    return $self->formeme_for_drop($t_node) if !$a_node;
    return $self->formeme_for_noun($t_node, $a_node) if $syntpos eq 'n';
    return $self->formeme_for_verb($t_node, $a_node) if $syntpos eq 'v';
    return $self->formeme_for_adj($t_node, $a_node) if $syntpos eq 'adj';
    return $self->formeme_for_adv($t_node, $a_node) if $syntpos eq 'adv';

    # If no such method is found, the formeme is unrecognized
    return '???';
}

# Formeme of generated nodes. Can be overriden.
sub formeme_for_drop {
    my ($self, $t_node) = @_;
    return '???';
}

# semantic adverbs
sub formeme_for_adv {
    my ($self, $t_node, $a_node) = @_;
    return 'adv';
}

# semantic nouns
sub formeme_for_noun {
    my ( $self, $t_node, $a_node ) = @_;

    # noun with a preposition (or postposition)
    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my $prep = $self->get_aux_string(@aux_a_nodes);
    return "n:$prep+X" if $prep;

    # possesive nouns
    return 'n:poss' if $a_node->get_iset('poss'); 

    # We need to know lex a-node of the effective parent of $t_node.
    # Check if it is missing (e.g. PEDT contains constructions with generated parent node #Equal).
    my $parent_a_node = $self->get_parent_anode($t_node, $a_node);
    return 'n:???' if !$parent_a_node;
    my $afun = $a_node->afun;

    if ( $parent_a_node->is_verb ) {

        # Let's have e.g.: "This year(afun=Adv), there were many errors in MT."
        # "year" is a semantic noun, but not subject nor object.
        # What formeme should it have? Martin Popel proposes n:adv.
        return 'n:adv'  if $afun eq 'Adv';
        return 'n:subj' if $afun eq 'Sb';
        return 'n:obj'  if $afun eq 'Obj';

        # If something went wrong (parser and consequently afun=NR)
        # try a guess - it is better than having formeme 'n:'.
        return 'n:subj' if $a_node->precedes($parent_a_node);
        return 'n:obj';
    }

    return 'n:poss' if any { $_->match_iset('pos' => 'part', 'poss' => 'poss') } @aux_a_nodes;
    return 'n:attr' if $self->below_noun($t_node) || $self->below_adj($t_node);
    return 'n:';
}

# semantic adjectives
sub formeme_for_adj {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my $prep        = $self->get_aux_string(@aux_a_nodes);
    
    return "n:$prep+X" if $prep; # adjectives with prepositions are treated as a nominal usage
    return 'adj:attr'  if $self->below_noun($t_node) || $self->below_adj($t_node);
    return 'n:subj'    if $a_node->afun eq 'Sb'; # adjectives in the subject positions -- nominal usage
    return 'adj:compl' if $self->below_verb($t_node);
    return 'adj:';
}

# semantic verbs
sub formeme_for_verb {
    my ( $self, $t_node, $a_node ) = @_;

    my @aux_a_nodes = $t_node->get_aux_anodes( { ordered => 1 } );
    my $first_verbform = ( first { $_->is_verb && $_->afun !~ /^Aux[CP]$/ } $t_node->get_anodes( { ordered => 1 } ) ) || $a_node;
    
    my $subconj = $self->get_subconj_string($first_verbform, @aux_a_nodes);

    # Infinitives
    if ( $a_node->get_iset('verbform') eq 'inf' ) {        
        return "v:$subconj+inf" if $subconj; # this includes the particle 'to'
        return 'v:inf';
    }

    # Gerunds (English -ing form is used both for gerunds and present participle, we handle both here, if syntpos=v)
    if ( $first_verbform->get_iset('verbform') eq 'ger' || $first_verbform->match_iset(verbform=>'part', tense=>'pres') ) {
        return "v:$subconj+ger" if $subconj;
        return 'v:attr' if $self->below_noun($t_node);
        return 'v:ger';
    }

    # Heads of finite clauses
    if ( $t_node->is_clause_head ) {
        return "v:$subconj+fin" if $subconj;            # subordinate clause introduced by a conjunction 
        return 'v:rc' if $t_node->is_relclause_head;    # relative subordinate clause
        return 'v:fin';
    }

    # Past participles and past simple (but not clause heads)
    if ( $first_verbform->get_iset('tense') eq 'past' ) {
        # if there is a subjunction, it mostly is a finite form (e.g. with ellided auxiliaries: "as compared ..." etc.)
        return "v:$subconj+fin" if $subconj;
        return 'v:attr' if $self->below_noun($t_node);
        return 'v:fin';
    }

    # now we don't know if it's infinitive or not (mostly parsing errors) -- assume finite forms
    return "v:$subconj+fin" if $subconj;

    # direct speech, imperatives, parsing errors (which in fact mostly are finite forms, if they're verbs at all)
    return 'v:fin';
}

sub get_aux_string {
    my $self = shift;
    my @preps_and_conjs = grep { $self->is_prep_or_conj($_) } @_;
    return join '_', map { lc $_->form } @preps_and_conjs;
}

sub get_parent_anode {
    my ($self, $t_node, $a_node) = @_;
    # special handling for root node (get_lex_anode does not work for it)
    my ($parent_t_node) = $t_node->get_eparents();
    my $parent_a_node =
        $parent_t_node->is_root()
        ? ( $a_node->get_eparents )[0]
        : $parent_t_node->get_lex_anode();
    return $parent_a_node;
}

sub is_prep_or_conj {
    my ($self, $a_node) = @_;
    return 1 if $a_node->afun =~ /Aux[CP]/;
    return 0;
}

sub get_subconj_string {
    my ($self, $first_verbform, @aux_a_nodes) = @_;
    
    @aux_a_nodes = grep { $_->precedes($first_verbform) } @aux_a_nodes; 
    return join '_', map { lc $_->form } grep { $self->is_prep_or_conj($_) } @aux_a_nodes;
}

sub below_noun {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return $self->detect_syntpos($eff_parent) eq 'n';
}

sub below_adj {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return $self->detect_syntpos($eff_parent) eq 'adj';
}

sub below_verb {
    my ($self, $tnode) = @_;
    my ($eff_parent) = $tnode->get_eparents() or return 0;
    return $self->detect_syntpos($eff_parent) eq 'v';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

This block serves as a base language-implementation using Interset morphological features.
language-specific implementation should override the methods where the base implementation is insufficient.
Note that the whole implementation (and especially C<formeme_for_verb>) are based on English
(so C<Treex::Block::A2T::EN::SetFormeme> needs to override only few methods).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
