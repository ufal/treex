package Treex::Block::W2A::JA::SetAfun;
use Moose;
use Treex::Core::Common;
#use Treex::Tool::Lexicon::JA;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    # Process heads of main clauses + the terminal punctuation (AuxK).
    # Then recursively process the whole tree.
    # (Rarely, there can be more terminal punctuations.!)
    # (There may be more heads and this is in case of coordinations.)
    foreach my $subroot ( $a_root->get_echildren() ) {
        $subroot->set_afun( get_afun_for_subroot($subroot) );
        process_subtree($subroot);
    }

    return 1;
}

sub get_afun_for_subroot {
    my ($subroot) = @_;

    my $afun = $subroot->afun;
    return $afun if $afun;

    my $lemma = $subroot->lemma;
    my $tag = $subroot->tag;

    return 'AuxK' if $subroot->form =~ /^[.?!]$/;
    
    # we set Pred Afun to Copulas and verbs
    return 'Pred' if ( $lemma eq "です" || $lemma eq "だ" || $tag =~ /^Dōshi/) ;
    return 'ExD';
}

 my $NOUN_REGEX = qr/^(NN|PRP|WP|CD$|WDT$|\$)/;

sub process_subtree {
    my ($node) = @_;
    foreach my $subject ( find_subjects_of($node) ) {
        $subject->set_afun('Sb');
    }

    foreach my $child ( $node->get_echildren() ) {
        if ( !$child->afun ) {
            $child->set_afun( get_afun($child) );
        }
        process_subtree($child);
    }
    return;
}

# Marks auxiliary verbs (tagged Jodōshi, except for Copulas) with afun=AuxV
# and returns the subject of $node if any.
# In case of coordinated subjects, returns all such subjects.
sub find_subjects_of {
    my ($node) = @_;
    my $tag = $node->tag;
    my @subjects;

    # Only verbs can have subjects (and auxiliary verb children)
    # return if $tag !~ /^(V|MD)/;

    # Mark all auxiliary verbs
    my @echildren = $node->get_echildren();
    foreach my $auxV ( grep { is_aux_verb( $_, $node ) } @echildren ) {
        $auxV->set_afun('AuxV');
    }

    # find subject, which should be indicated by "が" particle
    # (there are some exceptions; should be handled elsewhere)
    # TODO: can be done better
    @subjects = grep { $_->get_parent()->lemma eq "が"} @echildren ;
    if ( !@subjects ) {
    	# other possibility is that the topic indicated by "は" is subject
    	# (there are also exceptions)
    	@subjects = grep { $_->get_parent()->lemma eq "は"} @echildren ; 
    }  
   
    return @subjects;

    # TODO: detect coordinations    

}

sub _select_subjects {
    my (@nouns) = @_;

    # Most common case: just one noun before verb -> subject
    return $nouns[0] if @nouns == 1;

    # More than 1 noun before verb:
    if ( @nouns > 1 ) {

        # It can be a coordination "Peter and Paul went there."
        my @coordinated = grep { $_->is_member } @nouns;
        return @coordinated if @coordinated;

        # Try to filter out adverbial nouns, e.g.
        # "This summer, he sold a car."
        # "The luxury auto maker last year sold 1,214 cars" (real sentence, PennTB)
        my @non_adv = grep {!_is_adverbial_noun($_->lemma)} @nouns;

        # Try the the last noun (just a uncorroborated heuristics).
        return $nouns[-1] if !@non_adv;
        return $non_adv[-1];
    }
    return;
}

sub is_aux_verb {
    my ( $node, $eparent ) = @_;
    my $lemma = $node->lemma;
    my $tag = $node->tag;
    my $ep_tag = $eparent->tag;

    # We mark all Jodōshi except Copulas as auxiliary
    return 1 if ( $tag =~ /^Jodōshi/ && $lemma ne "です" && $lemma ne "だ" );

    # Verbs with verb parents are also marked as auxiliary
    return 1 if ( $tag =~ /^Dōshi/ && $ep_tag =~ /^Dōshi/ ) ;

    # For the time being we also mark "て" particle as auxiliary
    return 1 if ( $tag =~ /Setsuzoku/ && $lemma eq "て" ) ;

    return 0;
}

# Handle remaining afuns, i.e. all except Aux[CPV] and Sb.
sub get_afun {
    my ($node) = @_;
    my $tag = $node->tag;
    my $afun = $node->afun;
    return $afun if $afun;

    my $following = $node->get_next_node();
    return 'Pnom' if ( $following && ( $following->lemma eq "です" || $following->lemma eq "だ" ) );

    return 'Adv' if $tag =~ /^Fukushi/;

    # TODO: further modify for japanese

    # Possesive 's
    #return 'Atr' if $tag eq 'POS';

    # Particles of phrasal verbs
    #return 'AuxV' if $tag eq 'RP';

    # Punctuation
    # AuxK = terminal punctuation of a sentence
    # AuxG = other graphic symbols
    # AuxX = comma (not serving as Coord)
    my $form = $node->form;
    return 'AuxK' if $form =~ /[?!]/;
    return 'AuxX' if $form eq ',';

    # any punctuation, including ``, -LRB-, -RRB-, but excluding % wrongly assigned to the Unicode punctuation category
    return 'AuxG' if ( $form =~ /^(\p{Punct}+|-LRB-|-RRB-|``)$/ && $form ne '%' );

    # Articles a, an, the
    #my $lemma = $node->lemma;
    #return 'AuxA' if $lemma =~ /^(an?|the)$/ && $tag eq 'DT';

    # TODO: Negation 
    #return 'Neg' if $lemma eq 'not';

    # Precompute some values (eparent can be the root, so let's use undefs => '')
    #my ($eparent) = $node->get_eparents();
    #my ( $ep_tag, $ep_lemma, $ep_afun ) = $eparent->get_attrs(qw(tag lemma afun), { undefs => '' } );
    #my $ep_is_noun = ( $ep_tag =~ $NOUN_REGEX );
    #my $precedes_ep = $node->precedes($eparent);


    # TODO: Does Japanese have determiners?
    #    -  Do we need to detect them?

    # Determiners (except the already solved articles)
    #if ( $tag eq 'DT' ) {
    #    return 'Atr' if $ep_is_noun && $precedes_ep;
    #    return 'Adv' if $ep_tag =~ /^JJ/;
    #    return 'Obj' if $ep_tag =~ /^V/;
    #}

    # Adjectives and possesive pronouns ("your", "mine")
    # Most adjectives are Atr ($ep_is_noun) except for:
    # "It is red(parent=is, afun=Pnom)." ... copula verb (to be)
    # "It remains red(parent=remains, afun=Atr)." ... not considered a copula
    # according to http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s03.html#predsljm
    # "V našem pojetí za sponu pokládáme pouze sloveso být, ačkoli v běžných mluvnicích to bývá i stát se apod."
    #if ( $tag =~ /^(JJ|PRP\$)/ ) {
    #    return 'Pnom' if $ep_lemma eq 'be' && !$precedes_ep;
    #    return 'Atr';
    #}

    # Adverbs
    #if ( $tag =~ /^RB/ ) {
    #    return 'Atr' if $ep_is_noun;
    #    return 'Adv';
    #}

    # Nouns/Verbs/Numerals/Predeterminers as Atr
    #if ( $tag =~ $NOUN_REGEX || $tag =~ /^(V|MD|CD|PDT)/ ) {
    #    return 'Atr' if $ep_is_noun;
    #}

    # Nouns/determiners/verbs under preposition/subord. conjunction
    #my $grandpa = $eparent->get_parent();
    #my $i_am_noun = $tag =~ $NOUN_REGEX;
    #if ( ( $i_am_noun || $tag =~ /^(DT|V|MD)/ ) && $ep_afun =~ /Aux[PC]/ && $grandpa ) {
    #    my $grandpa_tag   = $grandpa->tag   || '_root';
    #    my $grandpa_lemma = $grandpa->lemma || '_root';

        # "This is of great interest(afun=Pnom,parent=of,grandpa=is)."
    #    return 'Pnom' if $grandpa_lemma eq 'be' && $ep_lemma eq 'of' && $grandpa->precedes($node);
    #    return 'Adv' if $grandpa_tag =~ /^(V|MD)/;
    #    return 'Atr' if $grandpa_tag =~ $NOUN_REGEX;
    #    return 'Adv' if $i_am_noun;
    #}

    # Nouns under verbs (but subjects are already solved)
    #if ( $i_am_noun && $ep_tag =~ /^(V|MD)/ ) {

        # "This month(afun=Adv), we are happy."
    #    return 'Adv' if _is_adverbial_noun($lemma);

        # "It is a dog(afun=Pnom)"
        # TODO: questions -- "Is immigration a burden for the economy?"
    #    return 'Pnom' if $ep_lemma eq 'be' && !$precedes_ep;

    #    return 'Obj' if !$precedes_ep || $tag =~ /^W/;
    #    return 'NR';
    #}

    # Verbs under verbs
    #if ( $tag =~ /^(V|MD)/ && $ep_tag =~ /^(V|MD)/ ) {

        # TODO: distinguish Obj and Adv by better rules
        # "I must|want|need|have to go(afun=Obj)"
    #    return 'Obj' if $ep_tag eq 'MD' || $ep_lemma =~ /^(have|need)$/;

        # "Go there to see(afun=Adv) it."
    #    return 'Adv';
    #}

    # And the rest - we don't know
    #return 'NR';
}

# Adverbials are usually expressed by prepositional phrases
# with a few exceptions - namely temporal modifiers expressed by nouns.
# This is just a heuristics - we guess wrong cases like
# "Do you remember that year?", but there's no English Vallex to help.
sub _is_adverbial_noun {
    my ($lemma) = @_;
    return 1 if $lemma =~ /^(year|month|week|spring|summer|autumn|winter)$/;
    return 1 if Treex::Tool::Lexicon::EN::number_of_month($lemma);
    return 0;
}

1;

__END__


=over

=item Treex::Block::W2A::JA::SetAfun

Fill the afun attribute by several heuristic rules.
Before applying this block, afun values C<Coord> (coordinating conjunction) and C<AuxP> (preposition) must be already filled.

At the moment only afuns important for block A2T::MarkEdgesToCollapse are filled. (TODO: fill all afun values correctly)

This block doesn't change already filled afun values, except for the C<Sb> afun.


=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
# Japanese part by Dusan Varis
