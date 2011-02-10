package SEnglishA_to_SEnglishT::Mark_edges_to_collapse;

use utf8;
use 5.008;
use strict;
use warnings;
use Readonly;
use List::MoreUtils qw( any all );
use List::Util qw( first);

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    foreach my $node ( $bundle->get_tree('SEnglishA')->get_descendants() ) {
        my $parent = $node->get_parent();

        # No node (except AuxK = terminal punctuation: ".?!")
        # can collapse to a technical root.
        if ( $parent->is_root() ) {
            if ( $node->get_attr('afun') eq 'AuxK' ) {
                $node->set_attr( 'edge_to_collapse', 1 );
                $node->set_attr( 'is_auxiliary',     1 );
            }
        }

        # Should collapse to parent because the $node is auxiliary?
        elsif ( is_aux_to_parent($node) ) {
            $node->set_attr( 'edge_to_collapse', 1 );
            $node->set_attr( 'is_auxiliary',     1 );
        }

        # Should collapse to parent because the $parent is auxiliary?
        elsif ( is_parent_aux_to_me($node) ) {
            $node->set_attr( 'edge_to_collapse', 1 );
            $parent->set_attr( 'is_auxiliary', 1 );
        }
    }
    return;
}

sub is_aux_to_parent {
    my ($node) = @_;
    my ( $tag, $lemma, $afun ) = $node->get_attrs(qw(m/tag m/lemma afun));

    # 1a) some afuns indicate that the node is aux to parent
    # AuxA = articles "a, an, the" (not an orginal PDT afun)
    # AuxK = terminal punctuation (now for direct speech)
    # AuxV = aux. verb (in English "be", "have", "will", "do", "to")
    # AuxX = comma not serving as a coordination conjunction
    # not AuxG = graphic symbols (dot not serving as terminal punct, colon etc.)
    #            These are quite hard to translate unless left as t-nodes.
    #            TODO: this leads to "Mr." being translated as "pan."
    return 1 if $afun =~ /Aux[AKVX]/;

    # 1b) some tags indicate that the node is aux to parent
    # RP = adverb particle (up, off, out), EX = existential there,
    # POS = possessive 's, -LRB- -RBR- brackets (not a Penn-style tag)
    # not quotes - just pragmatic reasons - easier way of translation
    #return 1 if $tag =~ /^(''|``)$/;
    return 1 if $tag =~ /^(RP|EX|POS|-NONE-|-LRB-|-RRB-)$/;

    # 1c) Prepositions and subord. conjunctions with no children
    # must collapse to parent. Otherwise, they would become t-nodes.
    # "I think that(tag=IN, parent=was) it was ..."
    # "... up to(tag=TO, parent=up) five(parent=percent) percent(parent=up)"
    my @children = $node->get_children();
    if ( $afun =~ /Aux[CP]/ ) {
        return 1 if !@children;

        # For multiword preps/conjs, the parsing could be also:
        # "up(afun=AuxP, parent=percent) to(afun=AuxP, parent=up) five percent"
        # "even(afun=AuxC, parent=was) though(afun=AuxC, parent=even) he was ..."
        # I.e. this node has just one child (Aux[CP]) and no grandchildren
        return 0 if @children > 1;
        my $child = $children[0];
        return 1 if $child->get_attr('afun') =~ /Aux[CP]/ && !$child->get_children();
    }

    # 1d) "More" and "most"
    # We are interested in the (first) effective parent.
    # If our tree-parent is a coord, the $node will collapse to this conjunction
    # and afterwards it will be distributed as aux to all members of the coordination.
    # Otherwise, our tree-parent is the same as effective parent.
    if ( $lemma =~ /^(more|most)$/ ) {
        my ($eparent) = $node->get_eff_parents();
        return 0 if $eparent->is_root();
        my $ep_tag = $eparent->get_attr('m/tag');
        return 1 && $ep_tag =~ /^(JJ|RB)/;
    }

    # In PDT-style, modal verbs should govern their main verbs,
    # but if something goes wrong ...
    my $p_tag = $node->get_parent()->get_attr('m/tag');
    return 1 if $p_tag =~ /^V/ && is_modal($lemma) && !any { $_->get_attr('m/tag') =~ /^V/ } @children;

    return 0;
}

sub is_parent_aux_to_me {
    my ($node) = @_;
    my $parent = $node->get_parent();
    my ( $tag, $lemma, $afun ) = $node->get_attrs(qw(m/tag m/lemma afun));
    my ( $p_tag, $p_form, $p_lemma, $p_afun ) = $parent->get_attrs(qw(m/tag m/form m/lemma afun));

    # Coordinations are tricky, we must inspect members instead of $node.
    # "He can sleep(parent=and) and(afun=Coord, parent=can) eat(parent=and)."
    # TODO: Why we get worse results by uncommenting following lines?
    #if ($afun eq 'Coord') {
    #    my $first_member = first {$_->get_attr('is_member')} $node->get_children();
    #    if ($first_member){
    #        $node = $first_member;
    #        ($tag, $afun ) = $node->get_attrs(qw(m/tag afun));
    #    }
    #}

    # 2a) Parent is a preposition or subord. conjunction
    # In PDT-like a-layer prepositions govern nouns (and conjunctions verbs).
    if ( $p_afun =~ /Aux[CP]/ && $afun !~ /Aux[CP]/ ) {
        ## First, get my non-aux siblings (including myself)
        # The grep is needed for multiword preps and conjs: "because of",
        # "As(afun=AuxC) long(afun=AuxC, parent=As) as(afun=AuxC, parent=As)
        #  he sleeps(tag=VBZ, parent=As)"
        my @siblings = grep { $_->get_attr('afun') !~ /Aux[CP]/ } $node->get_siblings( { ordered => 1 } );

        # I am the only non-aux child of my parent, that's nice
        return 1 if !@siblings;

        # Generally, preps and conjs have only one child, but now we have more.
        # Houston, we have a problem... Which child is the foster one?
        # We must ensure that only one child (the 'real' one) will be choosen,
        # because there can't be more than one lex.rf in a t-node.
        # Let's try some heuristics:
        # I am the only non-aux child after my parent
        # (preps and conjs in English stand before their 'real' child)
        my @siblings_after_prep = grep { $parent->precedes($_) } @siblings;
        return 1 if !@siblings_after_prep && $parent->precedes($node);

        # I am the foster child (there is a sibling after the parent)
        return 0 if @siblings_after_prep && !$parent->precedes($node);

        # For prepositions the 'real' child is a noun
        # "Particulary(tag=RB, parent=at) at(afun=AuxP) risk(tag=NN, parent=at)"
        # "... of(afun=AuxP) $(tag=$, parent=of) 10(parent=$) strange_word(parent=of)"
        # For conjunctions the 'real' child is a verb or a noun
        # Why nouns? "In case of errors..." No matter whether you call
        # in_case_of a phrasal conjunction or conjunctional preposition.
        my $wanted_regex = $p_afun eq 'AuxP' ? 'NN|CD|\$' : 'V|NN|CD|\$';

        # Let @siblings be all my sibling-rivals now and $rival the first one
        if ( $parent->precedes($node) ) { @siblings = @siblings_after_prep; }
        my $rival = first { $_->get_attr('m/tag') =~ /^($wanted_regex)/ } @siblings;

        # My tag looks good. And what about my rival?
        if ( $tag =~ /^($wanted_regex)/ ) {
            return 1 if !$rival;
            return $node->precedes($rival);
        }

        # Oterwise, choose the leftmost
        return $node->precedes( $siblings[0] );
    }

    # 2b) Modal verbs are governing their main verbs on a-layer.
    # "What would you do(tag=VB, parent=would)?"
    #return 1 if $tag =~ /^V/ && $parent->precedes($node) && is_modal($p_lemma);
    if ( is_modal($p_lemma) ) {
        return 0 if $node->precedes($parent) || ( $tag !~ /^V/ && $afun ne 'Coord' );
        my $rival = first { $_->get_attr('m/tag') =~ /^V/ && $parent->precedes($_) } $node->get_siblings( { ordered => 1 } );
        if ( $afun eq 'Coord' ) {
            $node = first { $_->get_attr('m/tag') =~ /^V/ } $node->get_children( { ordered => 1 } );
            return 0 if !$node;
        }
        return 1 if !$rival;
        return $node->precedes($rival);
    }

    # 2c) have/ought to
    # 'want' added by ZZ (not stricly modal in the sense of English grammar, but modal in FGD)
    # "You have to(tag=TO, parent=go) go(parent=have)."
    # The node "to" is also auxiliary, but that's job of 2a.
    if (($p_lemma =~ /^(have|ought|want)/ || $p_form eq "going") && $tag eq 'VB'){
        my $first_child = $node->get_children( { first_only => 1 } );
        return 1 if $first_child && $first_child->get_attr('m/lemma') eq 'to';
    }

    # 2d) be able to VB
    return 1 if $lemma eq 'able' && $p_lemma eq 'be';
    return 1 if $tag   eq 'VB'   && $p_lemma eq 'able';

    return 0;
}

sub is_modal {
    my ($lemma) = @_;
    return $lemma =~ /^(can|cannot|must|may|might|should|would|could|shall)$/;
}

1;

=over

=item SEnglishA_to_SEnglishT::Mark_edges_to_collapse

Before applying this block, afun values Aux[ACKPVX] and Coord must be filled.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
