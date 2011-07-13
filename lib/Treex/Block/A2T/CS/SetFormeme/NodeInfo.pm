package Treex::Block::A2T::CS::SetFormeme::NodeInfo;

use Moose;
use Treex::Core::Common;

require Treex::Tools::Lexicon::CS;

has 't' => ( is => 'ro', isa => 'Object', required => 1 );

has 't_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->t_lemma || '' } );

has 'a' => ( is => 'ro', isa => 'Maybe[Object]', lazy => 1, default => sub { $_[0]->t->get_lex_anode() } );

has 'tag' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->tag : '' } );

has 'lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->a ? $_[0]->a->lemma : '' } );

has 'sempos' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->t->gram_sempos || '' } );

has 'aux' => ( is => 'ro', isa => 'ArrayRef', lazy => 1, default => sub { [ $_[0]->t->get_aux_anodes( { ordered => 1 } ) ] } );

has 'case' => ( is => 'ro', isa => 'Str', lazy_build => 1 );

has 'prep' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->_prep_case->{prep} } );

has 'prepcase' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { $_[0]->_prep_case->{case} } );

has 'is_name_lemma' => ( is => 'ro', isa => 'Bool', lazy_build => 1 );

has 'trunc_lemma' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { Treex::Tools::Lexicon::CS::truncate_lemma( $_[0]->lemma, 1 ) } );

has 'term_types' => ( is => 'ro', isa => 'Str', lazy => 1, default => sub { Treex::Tools::Lexicon::CS::get_term_types( $_[0]->lemma ) } );

has 'is_term_label' => ( is => 'ro', isa => 'Bool', lazy => 1, default => sub { Treex::Tools::Lexicon::CS::is_term_label( $_[0]->lemma ) } );

has '_prep_case' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# Detects the case this word is in
sub _build_case {

    my ($self) = @_;

    if ( $self->tag =~ m/^[NAPC]...([1-7X])/ ) {
        return $1;
    }
    return '';
}

# Detects preposition + governed case / subjunction
sub _build__prep_case {

    my ($self) = @_;

    # default values for no prepositions
    my $ret = { 'prep' => '', 'case' => 'X' };

    # filter out punctuation, auxiliary / modal verbs and everything what's already contained in the lemma
    my @prep_nodes = grep {
        my $lemma = $_->lemma;
        $lemma = Treex::Tools::Lexicon::CS::truncate_lemma( $_->lemma, 1 );
        $lemma = lc( $_->form ) if $lemma eq 'se';    # way to filter out reflexives
        $_->tag !~ /^[VZ]/ and $self->t_lemma !~ /(^|_)$lemma(_|$)/
    } @{ $self->aux };

    if (@prep_nodes) {

        # find out the governed case; default for nominal and adverb constructions: genitive
        my $gov_prep = -1;
        while ( $gov_prep < @prep_nodes - 1 and ( !$self->a or $prep_nodes[ $gov_prep + 1 ]->ord < $self->a->ord ) ) {
            $gov_prep++;
        }
        my $gov_case = $prep_nodes[$gov_prep]->tag =~ m/^R...(\d)/ ? $1 : '';
        $gov_case = ( !$gov_case and $prep_nodes[$gov_prep]->tag =~ m/^[ND]/ ) ? 2 : $gov_case;

        # gather the preposition forms (lemma for the main preposition, to capture vocalic / non-vocalic forms, forms for nouns etc.)
        my @prep_forms = map { lc( $_->form ) } @prep_nodes;
        if ( $gov_prep >= 0 and $gov_prep < @prep_forms and $prep_nodes[$gov_prep]->tag =~ m/^R/ ) {
            $prep_forms[$gov_prep] = Treex::Tools::Lexicon::CS::truncate_lemma( $prep_nodes[$gov_prep]->lemma, 1 );
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

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::SetFormeme::NodeInfo

=head1 DESCRIPTION

A helper object for L<Treex::BLock::A2T::CS::SetFormeme> that collect all the needed information for a node from
both t-layer and a-layer, including preposition and case collected from aux-nodes and the surroundings of the node.

All values except C<a> and C<aux> are always set so no further checking is required.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
