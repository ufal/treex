package Treex::Block::A2T::CS::SetFormeme::NodeInfo;

use Moose;
use Treex::Core::Common;

use CzechMorpho;
require Treex::Tool::Lexicon::CS;
require Treex::Tool::Lexicon::CS::Numerals;

# The only required input attribute, the rest is (pre-)computed here
has 't' => ( is => 'ro', isa => 'Object', required => 1 );

# Fix inconsistencies caused by Czech numerals ?
has 'fix_numer' => ( is => 'ro', isa => 'Bool', default => 1 );

# Fix errors in preposition congruency ?
has 'fix_prep' => ( is => 'ro', isa => 'Bool', default => 1 );

# Analyse verbal diathesis, or stay with finite/infinite ?
has 'detect_diathesis' => ( is => 'ro', isa => 'Bool', default => 0 );

has 't_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->t_lemma || '' } );

has 'a' => ( is => 'ro', isa => 'Maybe[Object]', lazy => 1, default => sub { $_[0]->t->get_lex_anode() } );

has 'tag' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->tag : '' } );

has 'lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->lemma : '' } );

has 'sempos' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->gram_sempos || '' } );

has 'aux' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub { [ $_[0]->t->get_aux_anodes( { ordered => 1 } ) ] } );

has 'case' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has 'prep' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->_prep_case->{prep} } );

has 'is_name_lemma' => ( is => 'ro', isa => 'Bool', lazy_build => 1 );

has 'trunc_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { Treex::Tool::Lexicon::CS::truncate_lemma( $_[0]->lemma, 1 ) } );

has 'term_types' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { Treex::Tool::Lexicon::CS::get_term_types( $_[0]->lemma ) } );

has 'is_term_label' => ( is => 'ro', isa => 'Bool', lazy => 1, default => sub { Treex::Tool::Lexicon::CS::is_term_label( $_[0]->lemma ) } );

has '_prep_case' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

has '_analyzer' => ( is => 'rw', isa => 'Object', lazy => 1, default => sub { CzechMorpho::Analyzer->new() } );

has 'verbform' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has 'syntpos' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

# Detects the case this word is or should be in
sub _build_case {

    my ($self) = @_;
    my $prep;

    if ( $self->tag =~ m/^[NAPC]...([1-7X])/ ) {

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
        if ( $self->fix_prep and $prepcase ne 'X' and $case ne $prepcase ) {
            return 'X';
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

    # now we're screwed (we don't know 1 or 4); this happens with numbers, since they don't have case markings in tags
    else {
        return 'X';
    }
}

# Find (first) non-congruent numeral that governs this node on the a-layer but is governed by this node on the t-layer
sub _find_noncongruent_numeral {

    my ($self) = @_;

    return if ( $self->t->is_coap_root() );

    my %t_children = map { $a = $_->get_lex_anode; $a->id => $_ if $a } $self->t->get_echildren();
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

# Detects preposition + governed case / subjunction
sub _build__prep_case {

    my ($self) = @_;

    # default values for no prepositions
    my $ret = { 'prep' => '', 'case' => 'X' };

    # filter out punctuation, auxiliary / modal verbs and everything what's already contained in the lemma
    my @prep_nodes = grep {
        my $lemma = $_->lemma;
        $lemma = Treex::Tool::Lexicon::CS::truncate_lemma( $_->lemma, 1 );
        $lemma = lc( $_->form ) if $lemma eq 'se';    # way to filter out reflexives
        $_->tag !~ /^[VZ]/ and $self->t_lemma !~ /(^|_)$lemma(_|$)/
    } @{ $self->aux };

    if (@prep_nodes) {

        # find out the governed case; default for nominal and adverb constructions: genitive
        # TODO this may possibly be solved syntactically (the parent of the main node is the preposition), but is it more reliable?
        my $gov_prep = -1;
        while ( $gov_prep < @prep_nodes - 1 and ( !$self->a or $prep_nodes[ $gov_prep + 1 ]->ord < $self->a->ord ) ) {
            $gov_prep++;
        }
        my $gov_case = $prep_nodes[$gov_prep]->tag =~ m/^R...(\d)/ ? $1 : '';
        $gov_case = ( !$gov_case and $prep_nodes[$gov_prep]->tag =~ m/^[ND]/ ) ? 2 : $gov_case;

        # gather the preposition forms (lemma for the main preposition, to capture vocalic / non-vocalic forms, forms for nouns etc.)
        my @prep_forms = map { lc( $_->form ) } @prep_nodes;
        if ( $gov_prep >= 0 and $gov_prep < @prep_forms and $prep_nodes[$gov_prep]->tag =~ m/^R/ ) {
            $prep_forms[$gov_prep] = Treex::Tool::Lexicon::CS::truncate_lemma( $prep_nodes[$gov_prep]->lemma, 1 );
        }

        $ret->{prep} = join( '_', @prep_forms );
        $ret->{case} = $gov_case ? $gov_case : 'X';
    }

    return $ret;
}

sub _build_is_name_lemma {
    my ($self) = @_;

    return 1 if $self->term_types =~ m/[YSGKRm]/;

    return (
        substr( $self->trunc_lemma, 0, 1 ) eq uc( substr( $self->trunc_lemma, 0, 1 ) )
            and substr( $self->trunc_lemma, 1 ) eq lc( substr( $self->trunc_lemma, 1 ) )
    );
}

sub _build_verbform {
    my ($self) = @_;

    return '' if ( $self->sempos ne 'v' );
    my $finity = ( $self->tag =~ /^V[fme]/ and not grep { $_->tag =~ /^V[Bp]/ } @{ $self->aux } ) ? 'inf' : 'fin';

    return $finity if ( $finity eq 'inf' or !$self->detect_diathesis );

    return 'apass' if ( $self->tag =~ /^Vs/ );

    my ($verbal_synt_head) = grep { $self->a->parent == $_ } @{ $self->aux };
    $verbal_synt_head = $self->a if ( !$verbal_synt_head );

    return 'rpass' if ( grep { $_->afun eq 'AuxR' } $verbal_synt_head->children );

    return 'act';
}

sub _build_syntpos {
    my ($self) = @_;

    # skip conjunctions, prepositions, punctuations etc.
    return '' if ( $self->tag =~ m/^.[%#^,FIRTVXc]/ );

    # adjectives, adjectival numerals and pronouns
    return 'adj' if ( $self->tag =~ m/^.[\}=\?48ACDGLOSUadhklnrwyz]/ );

    # indefinite and negative pronous cannot be disambiguated simply based on POS (some of them are nouns)
    return 'adj' if ( $self->tag =~ m/^.[WZ]/ and $self->lemma =~ m/(žádný|čí|aký|který|[íý]koli|[ýí]si|ýs)$/ );

    # adverbs, adverbial numerals ("dvakrát" etc.)
    return 'adv' if ( $self->tag =~ m/^.[\*bgouv]/ );

    # verbs
    return 'v' if ( $self->tag =~ m/^V/ );

    # everything else are nouns: POS -- 567EHPNJQYj@X, no POS (possibly -- generated nodes)
    return 'n';
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
