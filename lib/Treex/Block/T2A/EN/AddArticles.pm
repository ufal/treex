package Treex::Block::T2A::EN::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN::Countability;
use Treex::Tool::Lexicon::EN::Hypernyms;

extends 'Treex::Core::Block';

my $DEBUG = 0;

has 'context_size' => ( isa => 'Int', is => 'ro', default => 7 );

has '_local_context' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

after 'process_document' => sub {
    my ($self) = @_;
    $self->_set_local_context( {} );    # clear local context after document
};

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode();

    # rule out personal pronouns and generated nodes
    return if ( $tnode->t_lemma =~ /^#/ );    # or ($tnode->functor // '') eq 'RSTR'
    return if ( !$anode );

    # rule out non-nouns
    return if ( ( $tnode->gram_sempos // '' ) !~ /^n/ and ( $anode->lemma // '' ) !~ /^(dozen|thousand|lot|deal)$/ );

    $self->decide_article( $tnode, $anode );
    return;
}

sub decide_article {
    my ( $self, $tnode, $anode ) = @_;
    my $lemma  = $anode->lemma           // '';
    my $number = $anode->morphcat_number // 'S';
    my $countability = Treex::Tool::Lexicon::EN::Countability::countability($lemma);
    my $article      = '';

    print STDERR "articles: $lemma\n" if $DEBUG;

    #
    # fixed rules
    #

    if ( _has_determiner($tnode) ) {
        $article = '';
        print STDERR "articles: has_determiner\n" if $DEBUG;
    }
    elsif ( _is_noun_premodifier($tnode) ) {
        $article = '';
        print STDERR "articles: is_noun_premodifier\n" if $DEBUG;
    }
    elsif ( $self->_local_context->{$lemma} ) {
        $article = 'the';
        print STDERR "articles: local_context\n" if $DEBUG;
    }
    elsif ( $tnode->gram_definiteness ) {
        $article = $tnode->gram_definiteness eq 'def1' ? 'the' : 'a';
        print STDERR "articles: gram/definiteness\n" if $DEBUG;
    }
    elsif ( _has_relative_clause($tnode) || _is_restricted_somehow( $tnode, $countability ) ) {
        $article = 'the';
        print STDERR "articles: has_relative_clause or is restricted\n" if $DEBUG;
    }
    elsif ( $countability eq 'countable' && $number eq 'S' ) {

        # John was President, Karl became Pope, Hey Doctor, come closer.
        $article = $lemma eq ucfirst($lemma) ? '' : _is_topic($anode) ? 'the' : 'a';
        print STDERR "articles: countable and singular\n" if $DEBUG;
    }
    elsif ( $countability eq 'countable' && $number eq 'P' ) {
        $article = '';
        print STDERR "articles: countable and plural\n" if $DEBUG;
    }
    elsif ( $countability eq 'uncountable' ) {

        # 'a' when modified by an adjective
        my @adj = grep { $_->gram_sempos =~ /^adj/ } $tnode->get_descendants();
        $article = scalar @adj ? 'a' : '';
        if ( $lemma =~ /^(pity|waste)$/ ) { $article = 'a' }
        print STDERR "articles: uncountable\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_meal($lemma) ) {
        $article = '';
        print STDERR "articles: meal\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_water_body($lemma) ) {
        $article = 'the';
        print STDERR "articles: ocean\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_island($lemma) ) {
        $article = $lemma =~ /\b(of)\b/ || $number eq 'P' ? 'the' : '';
        print STDERR "articles: island\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_peak($lemma) || $lemma =~ /mountain of /i ) {
        $article = $lemma =~ /\b(of)\b/ ? 'the' : '';
        print STDERR "articles: mountain\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_chain($lemma) ) {
        $article = 'the';
        print STDERR "articles: chain of mountains\n" if $DEBUG;
    }
    elsif ( $lemma =~ /^(Netherlands|Argentine)$/i ) {
        $article = 'the';
        print STDERR "articles: countries exceptions\n" if $DEBUG;
    }
    elsif ( $lemma =~ /\b(kingdom|union|state|republic|US|UK|U\.S\.)/i ) {
        $article = 'the';
        print STDERR "articles: kingdoms etc\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_country($lemma) ) {

        # other countries than above
        $article = '';
        print STDERR "articles: states\n" if $DEBUG;
    }
    elsif ( $lemma =~ /\b(union|EU)\b/i ) {
        $article = 'the';
        print STDERR "articles: eu\n" if $DEBUG;
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_nation($lemma) ) {

        # The French are strong, The Scottish are bald
        # BEWARE, this wont work, cos wn3.0 gives the 'people of a nation' into one synset with 'nation, land, country'
        # thus it will trigger the state test above
        $article = 'the';
        print STDERR "articles: nation\n" if $DEBUG;
    }
    elsif ( $lemma =~ /^(dozen|thousand)$/i ) {
        $article = '';

        # a thousand == one thousand
        $article = 'a' if $number eq 'S';
        print STDERR "articles: dozen\n" if $DEBUG;
    }
    elsif ( $lemma =~ /^(lot|deal)$/i ) {
        $article = 'a';
        print STDERR "articles: lot\n" if $DEBUG;
    }
    elsif ( $lemma =~ /^(left|right|center)$/i ) {
        $article = 'the';
        print STDERR "articles: direction\n" if $DEBUG;
    }

    #
    # probability rules below this point:
    #
    elsif ( $anode->get_attr('is_name') or $lemma eq ucfirst($lemma) ) {

        # Other names that above we want without the article
        $article = '';
        print STDERR "articles: is_name\n" if $DEBUG;
    }
    elsif ( _is_topic($anode) ) {
        $article = 'the';
        print STDERR "articles: is_topic\n" if $DEBUG;
    }
    else {

        # = 'the'; # 6mio in bnc, 2mio for 'a'
        $article = '';
        print STDERR "articles: default\n" if $DEBUG;
    }

    print STDERR "articles: $article\n\n" if $DEBUG;

    # grand finale
    if ($article) {
        add_article_node( $anode, $article );
    }

    # rough simulation of 7 salient items in consciousness, should be synsetid and not lemma
    $self->_add_to_local_context($lemma) if ( $article eq 'a' );
}

sub _has_determiner {
    my ($tnode) = @_;
    my @d = grep {
        $_->t_lemma =~ /^(some|this|those|that|these)$/
            or ( $_->gram_sempos // '' ) =~ /^(adj.pron.def.pers|n.pron.indef|adj.pron.def.demon)$/
    } $tnode->get_echildren();
    return scalar @d;
}

sub _is_noun_premodifier {
    my ($tnode) = @_;
    my $parent = $tnode->get_parent;
    return $tnode->formeme eq 'n:attr' and $parent->gram_sempos =~ /^n/ and $tnode->precedes($parent);
}

sub _is_topic {
    my ($anode) = @_;

    # TODO this won't probably work very well (we don't have deepord / TFA here)
    my $verb = $anode->get_clause_head();
    return $anode->precedes($verb);
}

sub _has_relative_clause {
    my ($tnode) = @_;
    my @relatives = ();
    my @relative_clause_heads = grep { $_->formeme eq 'v:rc' } $tnode->get_echildren();
    if (@relative_clause_heads) {
        @relatives = grep { $_->t_lemma eq 'which' } $relative_clause_heads[0]->get_echildren();
    }
    return scalar @relatives;
}

sub _is_restricted_somehow {
    my ($tnode) = @_;

    # TODO this won't probably work
    return scalar( grep { $_->functor eq 'LOC' } $tnode->get_children() );
}

sub add_article_node {
    my ( $anode, $lemma ) = @_;

    my $article = $anode->create_child(
        {
            'lemma'        => $lemma,
            'afun'         => 'AuxA',
            'morphcat/pos' => 'T',
            'conll/pos'    => 'DT'
        }
    );
    $article->shift_before_subtree($anode);

    #    TODO a -> an!!
    #    my ($first_node) = sort {
    #        $a->get_ordering_value() <=> $b->get_ordering_value()
    #    } $anode->get_treelet_nodes();
    #
    #    if ( $article eq 'a' and $first_node->get_attr('m/form') =~ /^[aeiou]/i ) {
    #        $form = 'an';
    #    }
    #
    #    $article->set_attr( 'm/form',  $form );
}

sub _add_to_local_context {
    my ( $self, $lemma ) = @_;

    $self->_local_context->{$lemma} = $self->context_size;

    foreach my $context_lemma ( keys %{ $self->_local_context } ) {
        $self->_local_context->{$context_lemma}--;
        delete $self->_local_context->{$context_lemma} if ( !$self->_local_context->{$context_lemma} );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to articles of nouns.

Using several heuristic rules to determine the article.

=head1 AUTHORS 

Jan Ptáček

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
