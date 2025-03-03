package Treex::Block::T2U::LA::BuildUtree;
use Moose;
extends 'Treex::Block::T2U::BuildUtree';

=head1 NAME

Treex::Block::T2U::LA::BuildUtree - Latin specifics of converting a t-tree to a u-tree

=head1 DESCRIPTION

This module implements actions depending on the lemmas and tags.

=cut

{   my %ASPECT_STATE;
    @ASPECT_STATE{qw{  }} = ();
    sub deduce_aspect {
        my ($self, $tnode) = @_;

        return 'state'
            if exists $ASPECT_STATE{ $tnode->t_lemma };

        my $a_node = $tnode->get_lex_anode or return 'state';
        my $tag = $a_node->tag;
        if ($tag =~ /^[vt]..(.)/) {
            my $tense = $1;
            return 'performance' if $tense =~ /^[rlt]$/;
            return 'activity'    if $tense =~ /^[pif]$/;
            return 'state'
        }
    }
}

__PACKAGE__->meta->make_immutable
