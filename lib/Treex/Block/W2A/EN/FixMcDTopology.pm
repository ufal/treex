package Treex::Block::W2A::EN::FixMcDTopology;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Lexicon::English;

# While recursively depth-first-traversing the tree
# we sometimes rehang already processed parent node as a child node.
# But we don't want to process such nodes again.
my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    # Auxiliary verbs (be, have, will, do) should depend on the main verb.
    # So if $a_node is the main verb and parent is an auxiliary verb, they are "switched"
    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;

    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }
    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    return 0 if $tag !~ /^V/;

    # We must consider coordinations as "He will drink and eat."
    # However, we can't use $a_node->get_eparents() since afuns are not filled yet.
    # So let's find effective parent using deprel instead.
    my $deprel  = $a_node->conll_deprel;
    my $eparent = $a_node->get_parent();
    return 0 if $eparent->is_root();
    if ( $deprel eq 'COORD' ) {

        # With coordinations, the deprel relevant to members
        # is saved in the coordination head.
        $deprel = $eparent->conll_deprel;

        $eparent = $eparent->get_parent();
        return 0 if $eparent->is_root();
    }

    # All auxiliary verbs processed in following steps (be, have, will, do)
    # must stand before the main verb ($a_node).
    return 0 if $a_node->precedes($eparent);

    my $ep_lemma = $eparent->lemma || '_root';

    # We want to switch auxiliary "be", e.g.:
    # "What are you doing(deprel=VC, tag=VBG, orig_parent=are)"
    # "It was done(deprel=VC, tag=VBN, orig_parent=was)."
    # but not "According(deprel=ADV, parent=is) to me, it is bad."
    #         "Given(deprel=ADV) ..."
    return 1 if $ep_lemma eq 'be' && $tag =~ /VB[NG]/ && $deprel ne 'ADV';

    # "It has solved(tag=VBN, orig_parent=has) our problems."
    return 1 if $ep_lemma eq 'have' && $tag eq 'VBN';

    # "It will solve(tag=VB, orig_parent=will) our problems."
    return 1 if $ep_lemma eq 'will' && $tag eq 'VB';

    # "It did not solve(tag=VB/VBP, orig_parent=did) anything".
    # "The people he does know(tag=VB/VBP, orig_parent=does) are rich.
    return 1 if $ep_lemma eq 'do' && $tag =~ /VBP?$/;

    # "to go(tag=VB)" Only in rare cases is "to" hanged above the infinitive
    return 1 if $ep_lemma eq 'to' && $tag eq 'VB';
    return 0;
}

sub switch_with_parent {
    my ($a_node) = @_;
    if ( $a_node->is_member == 1 ) {
        my $coord_head = $a_node->get_parent();
        my $eff_parent = $coord_head->get_parent();
        my $ggg        = $eff_parent->get_parent();
        $coord_head->set_parent($ggg);
        $eff_parent->set_parent($coord_head);
        my @eff_par_children = $eff_parent->get_children();
        for my $ch (@eff_par_children) {
            $ch->set_parent($coord_head);
        }
    }
    else {
        my $parent  = $a_node->get_parent();
        my $grandpa = $parent->get_parent();
        if ( $parent->is_member == 1 ) {
            $parent->set_is_member(0);
            $a_node->set_is_member(1);
        }
        $a_node->set_parent($grandpa);
        my @be_children = $parent->get_children();
        for my $ch (@be_children) {
            $ch->set_parent($a_node);
        }
        $parent->set_parent($a_node);
    }
    return;
}

1;

__END__

Deleted code:
# rehang 'to' before verbs, so it is a parent of the verb
if ( $tag eq 'TO' && $deprel eq 'VMOD' ) {
    $a_node->set_parent( $parent->get_parent() );
    $parent->set_parent($a_node);
    return;
}

Why should be "to" left hanging UNDER infinitives as it is in McD's output?

There are no official guidelines for English a-layer yet.
My reasons are pragmatically motivated, not linguistically.
After all, it's a matter of convention.

a) Otherwise, it's more work now when building a-layer and more work afterwards
 with building t-layer. When "to" is hanged above the infinitive, it must be
 handled separately, since all other aux verbs (be, do, have) are under the verb.

b) What afun should get "to" before infinitives?
 I decided to reuse AuxV (in Czech only with "be"), rather than to make up new afun name.
 But even if I have decided for something like AuxTO, the problem is the same:
   
 Methods TectoMT::Node::A::get_eff_children and get_eff_parents (and is_coap_member)
 rely on code $afun =~ /^Aux[CP]$/ i.e. only prepositions and subordinating conjunctions
 are "dived through" when looking for members of coordinations.
 When "to" is hanged under infinitive, there is no need to change that code.

Martin Popel

=over

=item Treex::Block::W2A::EN::FixMcDTopology

Modifies the topology of trees parsed by the McDonald's parser,
so it is more like PDT a-level: 
Auxiliary verbs (I<be, have, will, do>) should depend on the main verb, not vice versa.
Also I<to> as infinitive marker depends on the infinitive, but that is McD's default.  

Attributes C<is_member> must be filled before applying this block.

=back

=cut

# Copyright 2008-2009 Vaclav Novak, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
