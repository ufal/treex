package Treex::Block::Print::VWForDefiniteness;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
use Treex::Tool::FeatureExtract;
use Treex::Tool::Lexicon::EN::Countability;
use Treex::Tool::Lexicon::EN::Hypernyms;


extends 'Treex::Block::Print::VWVectors';


my $TARGETS = [ 'none', 'indefinite', 'definite' ];


has 'context_size' => ( isa => 'Int', is => 'ro', default => 30 );

enum DiscourseBreaks => [qw/ document sentence /];
has 'clear_context_after' => ( isa => 'DiscourseBreaks', is => 'ro', default => 'document' );

has '_local_context' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );


# routines clearing context
after 'process_document' => sub {
    my ($self) = @_;
    if ( $self->clear_context_after eq 'document' ) {
        $self->_set_local_context( {} );    # clear local context after document
    }
};

after 'process_bundle' => sub {
    my ($self) = @_;
    if ( $self->clear_context_after eq 'sentence' ) {
        $self->_set_local_context( {} );    # clear local context after each sentence
    }
};


# Skip everything but nouns
sub should_skip {
    my ( $self, $tnode ) = @_;
    return 1 if ( $tnode->formeme !~ /^n/ );
    return 0;
}

# Return all features as a VW string + the correct class (or undef, if not available)
# tag each class with its label + optionally sentence/word id, if they are set
sub get_feats_and_class {
    my ( $self, $tnode, $inst_id ) = @_;

    my $definiteness = $tnode->gram_definiteness || 'none';

    # get all features, formatted for VW
    my $feats = $self->_feat_extract->get_features_vw($tnode);
    push @$feats, @{ $self->get_custom_features($tnode) };

    # TODO make this filtering better somehow
    $feats = [ grep { $_ !~ /^(definiteness)[=:]/ } @$feats ];

    # format for the output
    my $feat_str = 'shared |S ' . join( ' ', @$feats ) . "\n";

    for ( my $i = 0; $i < @$TARGETS; ++$i ) {
        my $cost = '';
        my $tag = '\'' . ( $inst_id // '' ) . $TARGETS->[$i];
        $cost = ':' . ( $TARGETS->[$i] eq $definiteness ? 0 : 1 );
        if ( $TARGETS->[$i] eq $definiteness ) {
            $tag .= '--correct';
        }
        $feat_str .= ( $i + 1 ) . $cost . ' ' . $tag;
        $feat_str .= ' |T definiteness=' . $TARGETS->[$i] . "\n";
    }
    $feat_str .= "\n";
    return ( $feat_str, $definiteness );
}

sub get_custom_features {
    my ( $self, $tnode ) = @_;
    my $lemma  = $tnode->t_lemma     // '';
    my $number = $tnode->gram_number // 'sg';
    my $countability = Treex::Tool::Lexicon::EN::Countability::countability($lemma);
    my $article      = '';
    my $rule         = '?';
    my @feats        = ();

    # general features
    push @feats, 'countability=' . $countability;

    foreach my $context_lemma ( keys %{ $self->_local_context } ) {
        my $val = $self->_local_context->{$context_lemma} / $self->context_size;
        $context_lemma = Treex::Tool::FeatureExtract::_vw_escape($context_lemma);
        push @feats, 'context_' . $context_lemma . ':' . sprintf("%.4f", $val);
    }

    # conditional features
    push @feats, 'is_pronoun=1'            if ( _is_pronoun($tnode) );
    push @feats, 'has_determiner=1'        if ( _has_determiner($tnode) );
    push @feats, 'is_noun_premodifier=1'   if ( _is_noun_premodifier($tnode) );
    push @feats, 'in_local_context=1'      if ( $self->_local_context->{$lemma} );
    push @feats, 'has_relative_clause=1'   if ( _has_relative_clause($tnode) );
    push @feats, 'is_restricted_somehow=1' if ( _is_restricted_somehow( $tnode, $countability ) );

    if ( $countability eq 'countable' && $number eq 'sg' ) {
        push @feats, 'countable_and_singular_name=1'  if ( _is_name($tnode) );
        push @feats, 'countable_and_singular_topic=1' if ( _is_topic($tnode) );
    }
    elsif ( $countability eq 'countable' && $number eq 'pl' ) {
        push @feats, 'countable_and_plural=1';
    }
    elsif ( $countability eq 'uncountable' ) {

        push @feats, 'uncountable_with_adj=1' if ( grep { ( $_->gram_sempos // '' ) =~ /^adj/ } $tnode->get_descendants() );
        push @feats, 'uncountable/pity+waste=1' if ( $lemma =~ /^(pity|waste)$/ );
    }

    push @feats, 'meal=1'           if ( Treex::Tool::Lexicon::EN::Hypernyms::is_meal($lemma) );
    push @feats, 'ocean=1'          if ( Treex::Tool::Lexicon::EN::Hypernyms::is_water_body($lemma) );
    push @feats, 'island=1'         if ( Treex::Tool::Lexicon::EN::Hypernyms::is_island($lemma) );
    push @feats, 'mountain=1'       if ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_peak($lemma) );
    push @feats, 'mountain_chain=1' if ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_chain($lemma) );
    push @feats, 'country_the=1'    if ( $lemma =~ /^(Netherlands|Argentine)$/i or $lemma =~ /\b(kingdom|union|state|republic|US|UK|U\.S\.)/i );
    push @feats, 'country=1'        if ( Treex::Tool::Lexicon::EN::Hypernyms::is_country($lemma) );
    push @feats, 'union=1'          if ( $lemma =~ /\b(union|EU)\b/i );
    push @feats, 'nation=1'         if ( Treex::Tool::Lexicon::EN::Hypernyms::is_nation($lemma) );
    push @feats, 'dozen_thousand=1' if ( $lemma =~ /^(dozen|thousand)$/i );
    push @feats, 'lot_deal=1'       if ( $lemma =~ /^(lot|deal)$/i );
    push @feats, 'direction=1'      if ( $lemma =~ /^(left|right|center|bottom|top)$/i );
    push @feats, 'name=1'           if ( _is_name($tnode) );
    push @feats, 'topic=1'          if ( _is_topic($tnode) );

    # updating the context
    $self->_add_to_local_context($lemma);

    return \@feats;
}

sub _has_determiner {
    my ($tnode) = @_;
    my @d = grep {
        $_->t_lemma =~ /^(some|this|those|that|these|which|what|whose|one|no|any|no_one|nobody|nothing|none)$/
            or ( $_->gram_sempos // '' ) =~ /^(adj.pron.def.pers|n.pron.indef|adj.pron.def.demon)$/
            or $_->formeme eq 'n:poss'
    } $tnode->get_echildren({or_topological=>1});
    return scalar @d;
}

sub _is_noun_premodifier {
    my ($tnode) = @_;
    my $parent = $tnode->get_parent;
    return $tnode->formeme =~ /n:attr/ and $parent->gram_sempos =~ /^n/ and $tnode->precedes($parent);
}

sub _is_topic {
    my ($tnode) = @_;

    # Here we take advantage of the source (Czech) word order – it works better than when used
    # after reordering the sentence for English
    # N.B.: The issue is much more complex, this is an over-simplification.
    my $verb = $tnode->get_clause_head();
    return $tnode->precedes($verb);
}

sub _has_relative_clause {
    my ($tnode) = @_;
    my @relatives = ();
    my @relative_clause_heads = grep { $_->formeme eq 'v:rc' } $tnode->get_echildren({or_topological=>1});
    if (@relative_clause_heads) {
        @relatives = grep { $_->t_lemma eq 'which' } $relative_clause_heads[0]->get_echildren();
    }
    return scalar @relatives;
}

sub _is_restricted_somehow {
    my ($tnode) = @_;

    # unique identification: "the same/left/right/bottom..."
    return 1 if ( grep { $_->t_lemma =~ /^(same|left|right|top|bottom|first|second|third|last)$/ } $tnode->get_echildren({or_topological=>1}) );

    # superlatives: "the best, the greatest..."
    return 1 if ( grep { ( $_->gram_sempos // '' ) =~ /^adj.denot/ and ( $_->gram_degcmp // '' ) eq 'sup' } $tnode->get_echildren({or_topological=>1}) );

    # TODO this won't probably work
    return scalar( grep { ( $_->functor // '' ) eq 'LOC' } $tnode->get_children() );
}

my $PRONOUN = qr{
    \#PersPron|
    th(is|[oe]se|at)|
    wh(at|ich|o(m|se)?)(ever)?|
    (any|every|some|no)(body|one|thing)|each|n?either|(no[_ ])?one|
    both|few|many|several|
    all|any|most|none|some
}xi;

sub _is_pronoun {
    my ($tnode) = @_;

    return 1 if $tnode->t_lemma =~ /^($PRONOUN)$/;
    return 0;
}

sub _is_name {
    my ($tnode) = @_;

    # skip product names that work like regular nouns (TODO add more)
    return 0 if ( $tnode->t_lemma =~ /^(iPad|iPhone|iPod)$/ );
    return 1 if $tnode->is_name_of_person;
    return 1 if ( $tnode->src_tnode and $tnode->src_tnode->get_n_node() );
    return 1 if $tnode->t_lemma eq ucfirst( $tnode->t_lemma );
    return 0;
}

sub _add_to_local_context {
    my ( $self, $lemma ) = @_;

    $self->_local_context->{$lemma} = $self->context_size;

    foreach my $context_lemma ( keys %{ $self->_local_context } ) {
        $self->_local_context->{$context_lemma}--;
        delete $self->_local_context->{$context_lemma} if ( !$self->_local_context->{$context_lemma} );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::VWForDefiniteness

=head1 DESCRIPTION

Printing features for VowpalWabbit when detecting definiteness.

=head1 PARAMETERS

=over

=item context_size

Number of words to consider as "contextually activated".

=item clear_context_after

When the context activation is reset -- after document or after each sentence (use for unrelated sentences).

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
