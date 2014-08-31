package Treex::Block::W2A::EN::FixTagsAfterParse;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
extends 'Treex::Core::Block';

Readonly my $TAGS_FILE => 'data/models/morpho_analysis/en/forms_with_more_tags.tsv';

sub get_required_share_files { return $TAGS_FILE; }

# $CAN_BE{$tag}{$form} == 1 means that $form can have tag $tag
# Only forms with more possible tags are stored in this hash.
my %CAN_BE;

sub BUILD {
    my $self = shift;

    return;
}

sub process_start {
    my $self = shift;
    my $file_path = require_file_from_share($TAGS_FILE);
    open my $IN, '<:encoding(utf8)', $file_path or log_fatal $!;
    while (<$IN>) {
        chomp;
        my ( $form, @tags ) = split /\t/, $_;
        foreach my $tag (@tags) {
            $CAN_BE{$tag}{$form} = 1;
        }
    }
    close $IN;

    $self->SUPER::process_start();

    return;
}

# TODO: Should we change m-node's tag?
# In TectoMT there is no "knitting", so a-node's tag is only a copy of m-node's tag.
# There is a difference between:
# $a_node->set_tag($new_tag);
# $m_node->set_tag($new_tag);

sub process_atree {
    my ( $self, $a_root ) = @_;

    foreach my $a_node ( $a_root->get_descendants() ) {
        my ( $new_tag, $reparse ) = get_fixed_tag($a_node);
        if ($new_tag) {
            $a_node->set_tag($new_tag);
            $a_root->set_attr( 'reparse', 1 );
        }
    }

    return 1;
}

sub get_fixed_tag {
    my ($node)         = @_;
    my $tag            = $node->tag;
    my $form           = lc $node->form;
    my $parent         = $node->get_parent();
    my $eparent        = get_pseudo_eparent($node);
    my $ord            = $node->ord;
    my $follows_parent = $parent->ord + 1 == $ord;

    # "minus" as a noun
    # Mathematical operators (plus, minus, times, less, over) can be tagged
    # as CC (in PTB), but only if there is a real coordination.
    # So e.g. there is no coordination in "It falls to minus."
    if ( $form =~ /^(plus|minus|times)$/ && $tag eq 'CC' && !$node->get_children() ) {
        return $form eq 'times' ? 'NNS' : 'NN';
    }

    # Some phrasal verb particles (RP) are incorrectly tagged as RB
    if ( $form eq 'up' && $parent->lemma eq 'shoot' && $follows_parent ) {
        return 'RP';
    }

    # Clause heads are more likely to be verbs than nouns.
    # (It holds for all clauses, but here we can recognize only main clauses.)
    # E.g. word "cost" can be NN, VB, VBP, VBN or VBD, but if it was VB, VBP or VBN,
    # we hope the tagger would guess it correctly. So let's say it's VBD.
    if ( $eparent->is_root() ) {
        return 'VBD' if $tag eq 'NN'  && $CAN_BE{VBD}{$form};
        return 'VBZ' if $tag eq 'NNS' && $CAN_BE{VBZ}{$form};
        return;
    }

    my $ep_tag   = $eparent->tag;
    my $ep_lemma = $eparent->lemma;

    # Every modal verb should govern its main verb.
    # Sometimes is the main verb wrongly tagged as NN.
    if ( $tag =~ /^NN/ && $ep_tag eq 'MD' && $CAN_BE{VB}{$form} ) {
        my @siblings = get_pseudo_echildren($eparent);
        return 'VB' if !any { $_->tag =~ /^V/ } @siblings;
    }

    #return if can_be_child_and_parent($node, $eparent);
    #return 'NN' if $tag eq 'JJ' && $POSSIBLE_TAG_FORM{NN}{$form};

    return;
}

sub can_be_child_and_parent {
    my ( $child, $eparent ) = @_;
    my $c_tag   = $child->tag;
    my $p_tag   = $eparent->tag;
    my $p_lemma = $eparent->lemma;

    # Every modal verb should govern its main verb.
    # Sometimes is the main verb wrongly tagged as NN.
    if ( $c_tag =~ /^NN/ && $p_tag eq 'MD' ) {
        return any { $_->tag =~ /^V/ } get_pseudo_echildren($eparent);
    }
    return 1;
=item
    if ( $c_tag eq 'JJ' ) {
        return 1 if $p_tag =~ /^(N|CD|IN)/;
        return 1 if $p_lemma eq 'be' && $p_tag =~ /^V/;
        return 0;
    }

    #return 0 if $c_tag eq 'NN' && $p_tag eq 'MD';
    return 1;
=cut
}

# Next 2 methods need no afun filled (unlike $node->get_echildren())
sub get_pseudo_eparent {
    my ($node) = @_;
    my $parent = $node->get_parent();
    return $parent if $parent->is_root();
    while ( $parent->tag eq 'CC' ) {
        $parent = $parent->get_parent();
        return $parent if $parent->is_root();
    }
    return $parent;
}

sub get_pseudo_echildren {
    my ($node)       = @_;
    my @children     = $node->get_children();
    my @eff_children = ();
    while (@children) {
        my $child = shift @children;
        my @grandchildren = grep { $_->is_member } $child->get_children();
        if   (@grandchildren) { push @children,     @grandchildren; }
        else                  { push @eff_children, $child; }
    }
    return @eff_children;
}

1;

=over

=item Treex::Block::W2A::EN::FixTagsAfterParse

Some errors made by taggers can be detected after the parsing is done.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
