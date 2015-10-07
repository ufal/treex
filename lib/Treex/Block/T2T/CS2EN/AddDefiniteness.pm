package Treex::Block::T2T::CS2EN::AddDefiniteness;
use utf8;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN::Countability;
use Treex::Tool::Lexicon::EN::Hypernyms;

extends 'Treex::Core::Block';

has 'context_size' => ( isa => 'Int', is => 'ro', default => 7 );

enum DiscourseBreaks => [qw/ document sentence /];
has 'clear_context_after' => ( isa => 'DiscourseBreaks', is => 'ro', default => 'document' );

has '_local_context' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

after 'process_document' => sub {
    my ($self) = @_;
    if ($self->clear_context_after eq 'document') {
        $self->_set_local_context( {} );    # clear local context after document
    }
};

after 'process_bundle' => sub {
    my ($self) = @_;
    if ($self->clear_context_after eq 'sentence') {
        $self->_set_local_context( {} );    # clear local context after each sentence
    }
};

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # rule out personal pronouns and generated nodes
    return if ( $tnode->t_lemma =~ /^#/ );    # or ($tnode->functor // '') eq 'RSTR'
    
    # rule out non-nouns
    return if ( ( $tnode->gram_sempos // '' ) !~ /^n/ and ( $tnode->t_lemma // '' ) !~ /^(dozen|thousand|lot|deal)$/ );

    $self->decide_article( $tnode );
    return;
}

sub replace_some_with_indef {
    my ($self, $tnode, $countability) = @_;

    return 0 if ($countability && $countability ne 'countable');
    return 0 if (!defined $tnode->gram_number || $tnode->gram_number ne 'sg');
    my ($some_tnode) = grep {$_->t_lemma eq 'some'} $tnode->get_children;
    return 0 if (!defined $some_tnode);

    $some_tnode->remove({children=>'rehang'});
    $tnode->set_gram_definiteness('indefinite');
    return 1;
}

sub decide_article {
    my ( $self, $tnode ) = @_;
    my $lemma  = $tnode->t_lemma // '';
    my $number = $tnode->gram_number // 'sg';
    my $countability = Treex::Tool::Lexicon::EN::Countability::countability($lemma);
    my $article      = '';
    my $rule         = '?';

    #
    # fixed rules
    #

    if ( $self->replace_some_with_indef( $tnode, $countability ) ){
        $article = 'a';
        $rule = 'replace_some_with_indef';
    }
    elsif ( _has_determiner($tnode) ) {
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
    elsif ( _has_relative_clause($tnode) || _is_restricted_somehow( $tnode, $countability ) ) {
        $article = 'the';
        $rule    = 'has_relative_clause or is restricted';
    }
    elsif ( $countability eq 'countable' && $number eq 'sg' ) {

        # John was President, Karl became Pope, Hey Doctor, come closer.
        $article = $lemma eq ucfirst($lemma) ? '' : _is_topic($tnode) ? 'the' : 'a';
        $rule = 'countable and singular';
    }
    elsif ( $countability eq 'countable' && $number eq 'pl' ) {
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
        $article = $lemma =~ /\b(of)\b/ || $number eq 'pl' ? 'the' : '';
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
        $article = 'a' if $number eq 'sg';
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
    elsif ( $tnode->is_name_of_person or $lemma eq ucfirst($lemma) ) {

        # Other names that above we want without the article
        $article = '';
        $rule    = 'is_name';
    }
    elsif ( _is_topic($tnode) ) {
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
        $tnode->set_gram_definiteness($article eq 'the' ? 'definite' : 'indefinite');
    }
    log_info($tnode->t_lemma . ' ' . $rule . ' ' . $article);
    $tnode->wild->{article_rule} = $rule;  # store the rule for debugging purposes

    # rough simulation of 7 salient items in consciousness, should be synsetid and not lemma
    if ( $article eq 'a' or ( $rule =~ /(determiner|relative)/ and $countability eq 'countable' ) ){
        $self->_add_to_local_context($lemma);
    }
}

sub _has_determiner {
    my ($tnode) = @_;
    my @d = grep {
        $_->t_lemma =~ /^(some|this|those|that|these|which|what|whose|one|no|any|no_one|nobody|nothing|none)$/
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
    my ($tnode) = @_;

    # TODO this won't probably work very well (we don't have deepord / TFA here)
    my $verb = $tnode->get_clause_head();
    return $tnode->precedes($verb);
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
    
    # unique identification: "the same/left/right/bottom..."
    return 1 if ( grep { $_->t_lemma =~ /^(same|left|right|top|bottom|first|second|third|last)$/ } $tnode->get_echildren() );
    
    # superlatives: "the best, the greatest..."
    return 1 if ( grep { ( $_->gram_sempos // '' ) =~ /^adj.denot/ and ( $_->gram_degcmp // '' ) eq 'sup' } $tnode->get_echildren() );

    # TODO this won't probably work
    return scalar( grep { ( $_->functor // '' ) eq 'LOC' } $tnode->get_children() );
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
