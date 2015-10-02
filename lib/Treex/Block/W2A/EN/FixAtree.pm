package Treex::Block::W2A::EN::FixAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN;

my $last_form;

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @all_nodes = $a_root->get_descendants( { ordered => 1 } );

    return if !@all_nodes;

    # Terminal punctuation should hang on the technical root
    # So look for the last token
    my $last_node = $all_nodes[-1];
    $last_form = $last_node->form;

    # Terminal fullstop or question-mark can be followed by parenthesis or quotes
    if ( any { $_ eq $last_form } ( q{"}, q{''}, q{)}, q{'} ) ) {
        if ( @all_nodes == 1 ) {
            my $message = $last_node->get_address() . "\t Strange one-token sentence.";
            log_warn($message);

            #$bundle->leave_message($message);
            return;
        }
        $last_node = $all_nodes[-2];
        $last_form = $last_node->form;
    }

    # Rehang the last token, if it was a punctuation
    if ( $last_form =~ /^[.?!]$/ ) {
        $last_node->set_parent($a_root);
    }

    # Now for each node apply other rules
    foreach my $a_node (@all_nodes) {
        fix_node($a_node);
    }

    # Modal verbs should govern their main verbs, but sometimes it's the other way around.
    # This rule must be applied after several rules from fix_node.
    foreach my $node (@all_nodes) {
        if (( $node->parent->tag || 'root' ) =~ /^V/
            && is_modal( $node->lemma )
            && none { $_->tag =~ /^V/ } $node->get_echildren()
            )
        {
            my $parent = $node->get_parent();
            $node->set_parent( $parent->get_parent() );
            $parent->set_parent($node);
        }
    }

    # Check some frequent phrases which are not always parsed correctly
    foreach my $i ( 0 .. $#all_nodes - 2 ) {

        # 1. Phrases in form "much more/less RB/JJ" are badly parsed by McD
        my ( $much, $more, $adv ) = @all_nodes[ $i .. $i + 2 ];
        if ($much->lemma eq 'much'
            && $more->lemma =~ /^(more|less)$/
            && $adv->tag    =~ /^(RB|JJ)$/
            && $more->get_parent() == $much
            && $adv->get_parent() == $much
            )
        {
            $more->set_parent($adv);
            $adv->set_parent( $much->get_parent() );
            foreach my $child ( $much->get_children() ) {
                $child->set_parent($adv);
            }
            $much->set_parent($more);
            if ($much->is_member){
                $much->set_is_member(0);
                $adv->set_is_member(1);
            }
        }

        # 2. #TODO: for instance
    }

    return 1;
}

sub fix_node {
    my ($node) = @_;
    my ( $lemma, $tag, $is_member ) = $node->get_attrs(qw(lemma tag is_member));
    my $form      = lc $node->form;
    my @children  = $node->get_children( { ordered => 1 } );
    my $parent    = $node->get_parent();
    my $p_tag     = $parent->tag || '_root';
    my $p_lemma   = $parent->lemma || '_root';
    my $grandpa   = $parent->get_parent();
    my $g_tag     = ( $grandpa && !$grandpa->is_root() ) ? $grandpa->tag : '_root';
    my $g_lemma   = ( $grandpa && !$grandpa->is_root() ) ? $grandpa->lemma : '_root';
    my $ord       = $node->ord;
    my $next_node = $node->get_next_node();
    my $next_tag  = '';
    if ($next_node) { $next_tag = $next_node->tag; }

    # Rehang to first child, if ...
    # a) $node is a rhematizer or alike (that should not have children)
    if ( $lemma =~ /^(only|just|too|almost)$/ && @children ) {
        switch_with_first_child($node);
    }

    # b) "about(old_parent=errors, new_parent=100) 100(old_parent=about, new_parent=errors) errors"
    # Also the tag has to be fixed according to Penn treebank guidelines:
    # ``When used to mean "approximately" should be tagged as an adverb (RB),
    #   rather than a preposition.''
    if ( $lemma =~ /^(about|around|nearly)$/ && $node->precedes($parent) ) {
        switch_with_first_child($node);
        $node->set_afun('Atr');
        $node->set_tag('RB');
    }

    # "when" used as subord. conjunction should govern the relative clause
    if ($lemma eq 'when'
        && $p_tag =~ /^V/
        && $g_tag =~ /^V/
        && $node->precedes($parent)
        && !Treex::Tool::Lexicon::EN::is_dicendi_verb($g_lemma)
        )
    {
        $node->set_parent($grandpa);
        $parent->set_parent($node);
    }

    # other WH-pronouns should not have children, except for "how + adjective"
    elsif ( $tag =~ /^W/ && @children ) {

        my $adj_child;

        # find an adjective under 'how', rehang its children
        # TODO: 'how much of a boost the economy will have' and similar (rare), 'how American firms ... etc.'
        if ( $lemma eq 'how' && ( $adj_child = first { $_->tag eq 'JJ' || $_->lemma eq 'about' } @children ) ) {

            foreach my $grandchild ( $adj_child->get_children() ) {
                $grandchild->set_parent($parent);
            }
        }

        foreach my $child (@children) {
            if ( !$adj_child || $child != $adj_child ) {
                $child->set_parent($parent);
            }
        }
    }

    # Article "a" serving as a preposition "per" or "for"
    # "eight days a week" "$5 a day"
    if ($lemma eq 'a'
        && $g_tag =~ /^NN/
        && !@children
        && $grandpa->ord == $ord - 1
        )
    {
        $node->set_afun('AuxP');
        $node->set_parent($grandpa);
        $parent->set_parent($node);
    }

    # "from"& "to" should be siblings (children of their governing verb)
    # "go from(parent=go) A to(old_parent=from, new_parent=go) B"
    # "sleep from(parent=sleep) A till/untill(old_parent=from, new_parent=sleep) B"
    if ( $p_lemma eq 'from' && $lemma =~ /^(to|(un)?till)/ ) {
        $node->set_parent( $parent->get_parent() );
    }

    # Numerals should not be siblings (unless coordinated)
    # "over ten(tag=CD, old_parent=over, new_parent=thousand) thousand(tag=CD, parent=over)"
    if ( $tag eq 'CD' && !$is_member && $next_tag eq 'CD' && $next_node->get_parent() == $parent ) {
        $node->set_parent($next_node);
    }

    # Numeral should be a child of 'its' noun, not siblings
    # TODO: there are also other nouns (not only "Euro") where McD fails
    if ( $tag eq 'CD' && $next_node && $next_node->lemma =~ /^(euro|percent|dollar)$/i ) {
        if ( !$next_node->is_descendant_of($node) ) {
            $node->set_parent($next_node);
        }
        else {

            #TODO: $next_node is a descendant of $node, but it should be a parent.
            # What should we do?
        }
    }

    # Word "which" should be a left child of a verb in relative clauses:
    #   "He has the car which everyone knows."
    #   "He has the exam which students hate."
    # However, parsers can hang "which" on "everyone",
    # as if it was an indirect or direct question:
    #   "He asked me which students failed."
    #   "Which students failed?"
    if ( $lemma eq 'which' ) {

        # On the other hand, sometimes the parsing is wrong the opposite way:
        #   "Which(parent=failed) students failed?"
        if ( $p_tag =~ /^(V|MD)/ && $node->precedes($parent) ) {
            if ( $ord == 1 && $grandpa->is_root() && $last_form eq '?' && $next_tag =~ /^N/ ) {
                # Very rare case: "WHich(parent=watch) BBC(parent=WHich) do you watch?" 
                if ($next_node->parent == $node){
                    $next_node->set_parent($parent);
                }
                $node->set_parent($next_node);
            }
            return;
        }

        # Filter out cases where "which" doesn't have grandparent.
        # (These are not "which" in relative clauses.)
        return if !$grandpa || $grandpa->is_root();

        # Filter out cases where it is correct that parent is a noun:
        #   "He asked me which students failed."
        #   "Which students failed?"
        my $grandgrandpa = $grandpa->get_parent();
        return if $node->precedes($parent) &&
                (   $grandgrandpa->is_root()
                    || Treex::Tool::Lexicon::EN::is_dicendi_verb( $grandgrandpa->lemma )
                );

        # Process cases where parent is a preposition:
        # Prepositional parent is OK in phrases like "for which(parent=for)"
        # but even then it may be the preposition that is badly hanged.
        # The verb is usually the right sibling of which/preposition, but it is
        # better to check if it is really a verb, so we filter out exceptions as
        # "licences, the validity of(parent=validity) which(parent=of) will expire".
        if ( $p_tag =~ /IN|TO/ ) {
            return if $parent->precedes($grandpa);
            my $verb = $node->get_siblings( { following_only => 1, first_only => 1 } );
            if ( $verb && $verb->tag =~ /^(V|MD)/ ) {
                $verb->set_parent($grandpa);
                $parent->set_parent($verb);
            }
            return;
        }

        # Where is my real parent? First, try the nearest right sibling.
        my $verb = $node->get_siblings( { following_only => 1, first_only => 1 } );
        if ( $verb && $verb->tag =~ /^(V|MD)/ ) {
            $node->set_parent($verb);
            return;
        }

        # Second, try my ancestors (following me)
        while ( $node->precedes($parent) ) {
            if ( $parent->tag =~ /^(V|MD)/ ) {
                $node->set_parent($parent);
                return;
            }
            $parent = $parent->get_parent() or return;
        }

        # There is something wrong, but we failed to find a good parent for "which"
        return;
    }

    # Subordinating conjunctions under coord. are weird
    # Oops, this doesn't work as I thought.
    #my $p_tag = $parent->tag;
    #if ($tag eq 'IN' && !@children && $p_tag eq 'CC') {
    #    if ($grandpa && $grandpa->tag =~ /^(V|MD)/){
    #        $node->set_parent($grandpa);
    #    }
    #}

    # At present (5/2009), there are two problems with "because"
    # a) since it has afun=AuxC, it should govern the verb (or "because of noun")
    #    This should be solved in Fix_McD_topology, but it is not (yet).
    # b) "Work because you need money!" - here "work" should govern "need"
    #    (as for linguistics, not politics), but parser has different opinion.
    #    So fix it now.
    if ( $lemma eq 'because' && !@children && $p_tag ne 'CC' ) {
        my $verb = first { $_->tag =~ /^(V|MD)/ } $node->get_siblings( { preceding_only => 1 } );
        if ( $verb && !$parent->is_root() ) {
            $verb->set_parent($grandpa);
            $parent->set_parent($verb);
        }
    }

    # In phrases like "have done", "has gone" etc.,
    # verb "have" should depend on the next verb.
    if ( $lemma eq 'have' && $next_tag eq 'VBN' && $parent != $next_node ) {
        if ( !$next_node->is_descendant_of($node) ) {
            $node->set_parent($next_node);
        }
    }

    # Change "He is younger(parent=than) than(parent=is) me(parent=than)"
    # to     "He is younger(parent=is) than(parent=younger) me(parent=than)"
    if ( $form eq 'than' && @children == 2 ) {
        my ( $younger, $me ) = @children;
        if ( $younger->precedes($node) && $node->precedes($me) && $younger->tag =~ /..R$/ ) {
            $younger->set_parent($parent);
            $node->set_parent($younger);
        }
    }

    # Move dependents from firstname node to surname node
    my $parent_n_node = $parent->n_node;
    my $n_node        = $node->n_node;
    if ( $n_node && $parent_n_node && $n_node eq $parent_n_node && $n_node->get_attr('ne_type') =~ /^p/ ) {

        foreach my $child ( $node->get_children ) {
            $child->set_parent($parent);
        }
    }

    # Change "at least(parent=at) five(parent=at)"
    # to     "at(parent=five) least(parent=at) five"
    if ( $lemma eq 'at' && @children == 2 ) {
        my ( $least, $five ) = @children;
        if ( $least->lemma =~ /^(least|most)$/ ) {
            $five->set_parent($parent);
            $node->set_parent($five);
        }
    }

    return;
}

sub is_modal {
    my ($lemma) = @_;
    return $lemma =~ /^(can|cannot|must|may|might|should|would|could|shall)$/;
}

sub switch_with_first_child {
    my ($node) = @_;
    my ( $first_child, @other_children ) = $node->get_children() or return;
    my $parent = $node->get_parent();
    $first_child->set_parent($parent);

    # Determiners must be leaves (and $node will go under $first_child)
    if ($first_child->tag eq 'DT'){
        $first_child = $parent;
    }


    foreach my $child (@other_children) {
        if ( $child->lemma eq 'of' ) {
            $child->set_parent($first_child);
        }
        else {
            $child->set_parent($parent);
        }
    }
    $node->set_parent($first_child);
    return;
}

1;

=over

=item Treex::Block::W2A::EN::FixAtree

Fix some errors made by parsers
(namely McDonald's one, but could be useful for others).

=back

=cut

# Copyright 2009-2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
