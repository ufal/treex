package Treex::Block::T2A::EN::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN::Countability;
use Treex::Tool::Lexicon::EN::Hypernyms;

extends 'Treex::Core::Block';

has 'grammateme_only' => ( isa => 'Bool', is => 'ro', default => 0 ); 

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
    
    # override rules and use just the gram_definiteness attribute
    if ( $self->grammateme_only ){
        if ($tnode->gram_definiteness){
            my $article_anode = add_article_node( $anode, $tnode->gram_definiteness eq 'definite' ? 'the' : 'a' );
            $tnode->add_aux_anodes($article_anode);
        }
        return;
    }

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
    my $rule         = '?';

    #
    # fixed rules
    #

    if ( _has_determiner($tnode) ) {
        $article = '';
        $rule    = 'has_determiner';
    }
    elsif ( _is_noun_premodifier($tnode) ) {
        $article = '';
        $rule    = 'is_noun_premodifier';
    }
    elsif ( $self->_local_context->{$lemma} ) {
        $article = 'the';
        $rule    = 'local_context';
    }
    elsif ( $tnode->gram_definiteness ) {
        $article = $tnode->gram_definiteness eq 'def1' ? 'the' : 'a';
        $rule = 'gram/definiteness';
    }
    elsif ( _has_relative_clause($tnode) || _is_restricted_somehow( $tnode, $countability ) ) {
        $article = 'the';
        $rule    = 'has_relative_clause or is restricted';
    }
    elsif ( $countability eq 'countable' && $number eq 'S' ) {

        # John was President, Karl became Pope, Hey Doctor, come closer.
        $article = $lemma eq ucfirst($lemma) ? '' : _is_topic($anode) ? 'the' : 'a';
        $rule = 'countable and singular';
    }
    elsif ( $countability eq 'countable' && $number eq 'P' ) {
        $article = '';
        $rule    = 'countable and plural';
    }
    elsif ( $countability eq 'uncountable' ) {

        $rule    = 'uncountable';
        $article = '';

        # 'a' when modified by an adjective
        if ( grep { ( $_->gram_sempos // '' ) =~ /^adj/ } $tnode->get_descendants() ) {
            $article = 'a';
            $rule    = 'uncountable/with adj';
        }
        elsif ( $lemma =~ /^(pity|waste)$/ ) {
            $article = 'a';
            $rule    = 'uncountable/pity+waste';
        }
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_meal($lemma) ) {
        $article = '';
        $rule    = 'meal';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_water_body($lemma) ) {
        $article = 'the';
        $rule    = 'ocean';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_island($lemma) ) {
        $article = $lemma =~ /\b(of)\b/ || $number eq 'P' ? 'the' : '';
        $rule = 'island';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_peak($lemma) || $lemma =~ /mountain of /i ) {
        $article = $lemma =~ /\b(of)\b/ ? 'the' : '';
        $rule = 'mountain';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_mountain_chain($lemma) ) {
        $article = 'the';
        $rule    = 'chain of mountains';
    }
    elsif ( $lemma =~ /^(Netherlands|Argentine)$/i ) {
        $article = 'the';
        $rule    = 'countries exceptions';
    }
    elsif ( $lemma =~ /\b(kingdom|union|state|republic|US|UK|U\.S\.)/i ) {
        $article = 'the';
        $rule    = 'kingdoms etc';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_country($lemma) ) {

        # other countries than above
        $article = '';
        $rule    = 'states';
    }
    elsif ( $lemma =~ /\b(union|EU)\b/i ) {
        $article = 'the';
        $rule    = 'eu';
    }
    elsif ( Treex::Tool::Lexicon::EN::Hypernyms::is_nation($lemma) ) {

        # The French are strong, The Scottish are bald
        # BEWARE, this wont work, cos wn3.0 gives the 'people of a nation' into one synset with 'nation, land, country'
        # thus it will trigger the state test above
        $article = 'the';
        $rule    = 'nation';
    }
    elsif ( $lemma =~ /^(dozen|thousand)$/i ) {
        $article = '';

        # a thousand == one thousand
        $article = 'a' if $number eq 'S';
        $rule = 'dozen';
    }
    elsif ( $lemma =~ /^(lot|deal)$/i ) {
        $article = 'a';
        $rule    = 'lot';
    }
    elsif ( $lemma =~ /^(left|right|center)$/i ) {
        $article = 'the';
        $rule    = 'direction';
    }

    #
    # probability rules below this point:
    #
    elsif ( $anode->get_attr('is_name') or $lemma eq ucfirst($lemma) ) {

        # Other names that above we want without the article
        $article = '';
        $rule    = 'is_name';
    }
    elsif ( _is_topic($anode) ) {
        $article = 'the';
        $rule    = 'is_topic';
    }
    else {

        # = 'the'; # 6mio in bnc, 2mio for 'a'
        $article = '';
        $rule    = 'default';
    }
    
    #
    # create the node and add it to context, if possible
    #
    if ($article) {
        my $article_anode = add_article_node( $anode, $article );
        $tnode->add_aux_anodes($article_anode);
    }
    $anode->wild->{article_rule} = $rule;  # store the rule for debugging purposes

    # rough simulation of 7 salient items in consciousness, should be synsetid and not lemma
    if ( $article eq 'a' or ( $rule =~ /(determiner|relative)/ and $countability eq 'countable' ) ){
        $self->_add_to_local_context($lemma);
    }
}

sub _has_determiner {
    my ($tnode) = @_;
    my @d = grep {
        $_->t_lemma =~ /^(some|this|those|that|these)$/
            or ( $_->gram_sempos // '' ) =~ /^(adj.pron.def.pers|n.pron.indef|adj.pron.def.demon)$/
            or $_->formeme eq 'n:poss'
    } $tnode->get_echildren();
    return scalar @d;
}

sub _is_noun_premodifier {
    my ($tnode) = @_;
    my $parent = $tnode->get_parent;
    return $tnode->formeme =~ /n:attr/ and $parent->gram_sempos =~ /^n/ and $tnode->precedes($parent);
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
            'form'         => $lemma,
            'afun'         => 'AuxA',
            'morphcat/pos' => 'T',
            'conll/pos'    => 'DT',
        }
    );
    $article->shift_before_subtree($anode);
    return $article;
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

Treex::Block::T2A::EN::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to articles of nouns.

Using several heuristic rules to determine the article. Rules will be overridden
by the values of the definiteness grammateme if C<grammateme_only> is set to C<1>.

=head1 AUTHORS 

Jan Ptáček

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
