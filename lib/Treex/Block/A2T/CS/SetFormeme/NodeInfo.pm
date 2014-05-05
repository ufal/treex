package Treex::Block::A2T::CS::SetFormeme::NodeInfo;

use Moose;
use Treex::Core::Common;

require Treex::Tool::Lexicon::CS;
require Treex::Tool::Lexicon::CS::Numerals;
require Treex::Tool::Lexicon::CS::NamedEntityLabels;

# The only required input attribute, the rest is (pre-)computed here
has 't' => ( is => 'ro', isa => 'Object', required => 1 );

# Fix inconsistencies caused by Czech numerals ?
has 'fix_numer' => ( is => 'ro', isa => 'Bool', default => 1 );

# Fix errors in preposition congruency ?
has 'fix_prep' => ( is => 'ro', isa => 'Bool', default => 1 );

has 't_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->t_lemma || '' } );

has 'a' => ( is => 'ro', isa => 'Maybe[Object]', lazy => 1, default => sub { $_[0]->t->get_lex_anode() } );

has 'tag' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->tag : '' } );

has 'afun' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->afun : '' } );

has 'lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->lemma : '' } );

has 'sempos' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->gram_sempos || '' } );

has 'aux' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub { [ $_[0]->t->get_aux_anodes( { ordered => 1 } ) ] } );

has 'case' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has 'prep' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->_prep_case->{prep} } );

has 'trunc_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { Treex::Tool::Lexicon::CS::truncate_lemma( $_[0]->lemma, 1 ) } );

has 'is_term_label' => ( is => 'ro', isa => enum( [ '', 'congr', 'incon' ] ), lazy => 1, default => sub { Treex::Tool::Lexicon::CS::NamedEntityLabels::is_label( $_[0]->lemma ) } );

has 'is_geo_congr_label' => ( is => 'ro', isa => 'Bool', lazy => 1, default => sub { Treex::Tool::Lexicon::CS::NamedEntityLabels::is_geo_congr_label( $_[0]->lemma ) } );

has 'ne_type' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has '_prep_case' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

has '_analyzer' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub { require CzechMorpho; CzechMorpho::Analyzer->new() } );

has 'verbform' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has 'syntpos' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

# Detects the case this word is or should be in
sub _build_case {

    my ($self) = @_;
    my $prep;

    # use only prepositions for generated nodes (their case is not reliable in case of ellipsis)
    if ( $self->t->is_generated && $self->sempos =~ m/^(n|adj)/ ) {
        return $self->_prep_case->{case};
    }

    # infer the case from preposition with non-declinable numerals and unknown words, if possible
    if ( $self->tag =~ m/^[XC]...-/ and $self->_prep_case->{case} ) {
        return $self->_prep_case->{case};
    }

    # other unknown words get 'X' (as they're mainly treated as substantives)
    elsif ( $self->tag =~ m/^X/ ) {
        return 'X';
    }

    # the main case -- declinable parts of speech
    elsif ( $self->tag =~ m/^[NAPC]...([1-7X])/ ) {

        my $case     = $1;
        my $prepcase = $self->_prep_case->{case};

        # infer the case from the preposition (if there is one), if the word's own case is not visible
        if ( $case eq 'X' ) {
            return $prepcase;
        }

        # change the case for non-congruent numerals, if supposed to
        if ( $self->fix_numer and $case eq '2' and ( my $numeral = $self->_find_noncongruent_numeral() ) ) {
            return $self->_get_fix_numer_case($numeral);
        }

        # if the case is not consistent with the preposition, return X, if supposed to
        if ( $prepcase ne 'X' and $case ne $prepcase ) {
            return $self->fix_prep ? 'X' : $prepcase;
        }
        return $case;
    }
    return '';
}

# Try to fix the case indication, if there is a non-congruent numeral and this word is its genitive attribute
sub _get_fix_numer_case {

    my ( $self, $numeral ) = @_;

    # infer the case from the numeral itself (if visible)
    if ( $numeral and $numeral->tag =~ m/^....([1-7])/ ) {
        return $1;
    }

    # infer the case from the word's own preposition
    elsif ( $self->_prep_case->{case} ne 'X' ) {
        return $self->_prep_case->{case};
    }

    # a heuristics: try to infer the case from the syntactic function (Sb, Pnom, ExD is nominative,
    # Atr tends to be something between nominative and genitive "v hodnotě 6 mil. korun", Adv and Obj is usually accusative)
    elsif ( $numeral->afun =~ m/^(ExD|Pnom|Sb|Obj|Atr|Adv)$/ ) {
        return $numeral->afun =~ /^(ExD|Pnom|Sb|Atr)$/ ? 1 : 4;
    }

    # now we're screwed (we don't know 1 or 4); this happens with numbers, since they don't have case markings in tags
    else {
        return 'X';
    }
}

# Find (first) non-congruent numeral that governs this node on the a-layer but is governed by this node on the t-layer
sub _find_noncongruent_numeral {

    my ($self) = @_;

    return if ( $self->t->is_coap_root() );

    my %t_children = map { $_->get_lex_anode->id => $_ } grep { $_->get_lex_anode } $self->t->get_echildren( { or_topological => 1 } );
    my @a_parents = $self->a->get_eparents( { or_topological => 1 } );

    foreach my $a_parent (@a_parents) {
        if ( $t_children{ $a_parent->id } ) {
            my $a_child = $t_children{ $a_parent->id }->get_lex_anode();
            if ( $a_child and Treex::Tool::Lexicon::CS::Numerals::is_noncongr_numeral( $a_child->lemma, $a_child->tag ) ) {
                return $a_parent;
            }
        }
    }
    return;
}

sub _get_prep_nodes {

    my ($self) = @_;

    # filter punctuation, reflexive pronouns and auxiliary verbs always, prepositions only for verbs
    my $pos_filter = $self->syntpos eq 'v' ? '([RVZ]|P7)' : '([VZ]|P7)';
    my @prep_nodes;

    for ( my $i = 0; $i < @{ $self->aux }; ++$i ) {
        my $cand = $self->aux->[$i];
        my $cand_lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $cand->lemma, 1 );

        # filter out punctuation, auxiliary / modal verbs and everything that's already contained in the lemma
        # keep prepositions for verbs if followed by an expletive pronoun
        if ((   $cand->tag !~ /^$pos_filter/
                || ( $cand->tag =~ /^R/ && any { $_->tag =~ /^PD/ } @{ $self->aux }[ $i .. $#{ $self->aux } ] )
            )
            and $self->t_lemma !~ /(^|_)\Q$cand_lemma\E(_|$)/
            )
        {
            push @prep_nodes, $cand;
        }
    }
    return @prep_nodes;
}

# Detects preposition + governed case / subjunction
sub _build__prep_case {

    my ($self) = @_;

    # default values for no prepositions
    my $ret = { 'prep' => '', 'case' => 'X' };

    my @prep_nodes = $self->_get_prep_nodes();

    if (@prep_nodes) {

        # find out the governed case; default for nominal and adverb constructions: genitive
        # TODO this may possibly be solved syntactically (the parent of the main node is the preposition), but is it more reliable?
        my $gov_prep = -1;
        while ( $gov_prep < @prep_nodes - 1 and ( !$self->a or $prep_nodes[ $gov_prep + 1 ]->ord < $self->a->ord ) ) {
            $gov_prep++;
        }
        my $gov_case = $prep_nodes[$gov_prep]->tag =~ m/^R...(\d)/ ? $1 : '';
        $gov_case = ( !$gov_case and $prep_nodes[$gov_prep]->tag =~ m/^[ND]/ ) ? 2 : $gov_case;

        # gather the auxiliaries' forms (lemma for subjunctions and the main preposition, in order to omit vocalization)
        my @prep_forms =
            map { $_->tag =~ m/^J,/ ? Treex::Tool::Lexicon::CS::truncate_lemma( $_->lemma, 1 ) : lc( $_->form ) }
            @prep_nodes;

        if ( $gov_prep >= 0 and $gov_prep < @prep_forms and $prep_nodes[$gov_prep]->tag =~ m/^R/ ) {
            $prep_forms[$gov_prep] = Treex::Tool::Lexicon::CS::truncate_lemma( $prep_nodes[$gov_prep]->lemma, 1 );
        }

        $ret->{prep} = join( '_', @prep_forms );
        $ret->{case} = $gov_case ? $gov_case : 'X';
    }

    return $ret;
}

sub _build_verbform {
    my ($self) = @_;

    return '' if ( $self->syntpos ne 'v' );

    return 'rc' if ( $self->t->is_relclause_head );

    # finite aux -> finite form
    return 'fin' if ( any { $_->tag =~ /^V[Bp]/ } @{ $self->aux } );

    # active infinitive / transgressive || passive infinitive
    return 'inf' if ( $self->tag =~ /^V[fme]/ || ( $self->tag =~ /^Vs/ && grep { $_->lemma eq 'být' } @{ $self->aux } ) );

    # default: finite
    return 'fin';
}

sub _build_syntpos {
    my ($self) = @_;

    # skip technical root, conjunctions, prepositions, punctuation etc.
    return '' if ( $self->t->is_root or $self->tag =~ m/^.[%#,FRVXc:]/ );

    return 'x' if ( $self->tag =~ m/^J\^/ );

    # adjectives, adjectival numerals and pronouns
    return 'adj' if ( $self->tag =~ m/^.[\}=\?148ACDGLOSUadhklnrwyz]/ );

    # indefinite and negative pronous cannot be disambiguated simply based on POS (some of them are nouns)
    return 'adj' if ( $self->tag =~ m/^.[WZ]/ and $self->lemma =~ m/(žádný|čí|aký|který|[íý]koli|[ýí]si|ýs)$/ );

    # adverbs, adverbial numerals ("dvakrát" etc.),
    # including interjections and particles (they behave the same if they're full nodes on t-layer)
    return 'adv' if ( $self->tag =~ m/^.[\*bgouvTI]/ );

    # verbs
    return 'v' if ( $self->tag =~ m/^V/ );

    # everything else are nouns: POS -- 5679EHPNJQYj@X, no POS (possibly -- generated nodes)
    return 'n';
}

sub _build_ne_type {
    my ($self) = @_;
    my $n_node = $self->a->n_node;

    return '' if ( !$n_node );
    return $n_node->ne_type;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::SetFormeme::NodeInfo

=head1 SYNOPSIS

    my $node_info = Treex::Block::A2T::CS::SetFormeme::NodeInfo->new( t => $t_node );

    print( $node_info->sempos . ' '. $node_info->prep . ' ' . $node_info->case );

=head1 DESCRIPTION

A helper object for L<Treex::BLock::A2T::CS::SetFormeme> that collects all the needed information for a node from
both t-layer and a-layer, including preposition and case collected from aux-nodes and surroundings of the node.

All values except C<a> and C<aux> are always set (albeit sometimes empty), so no further checking is required.

=head1 TODO

Remove the dependency to Treex::Block::A2T::CS::FixNumerals by creating a common library (where?)

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
