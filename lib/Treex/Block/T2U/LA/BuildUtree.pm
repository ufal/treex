package Treex::Block::T2U::LA::BuildUtree;
use Moose;
extends 'Treex::Block::T2U::BuildUtree';
with 'Treex::Tool::UMR::LA::GrammatemeSetter';

=head1 NAME

Treex::Block::T2U::LA::BuildUtree - Latin specifics of converting a t-tree to a u-tree

=head1 DESCRIPTION

This module implements actions depending on the lemmas and tags.

=cut

{   my %ASPECT_STATE;
    @ASPECT_STATE{qw{ amo arbitror audio aueo aveo cognosco confido credo
                      cupio debeo desidero dubito existimo exopto exspecto
                      fido foeteo habeo intueor invideo licet malo memini nolo
                      nosco oboleo odi oleo opinor opto possum praesumo puteo
                      puto recordor reminiscor reor sapio scio sentio spero
                      suspicor ualeo uideo valeo video volo^velle }} = ();
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

sub is_morpho_negated {
    my ($self, $anode) = @_;
    return 0
}

sub fix_errors {
    my ($self, $tnode) = @_;

    # More than one top node.
    if (! $tnode->parent && 1 < $tnode->children) {
        my @children = $tnode->children;
        my $separ = $tnode->create_child;
        $separ->set_t_lemma('#Separ');
        $separ->set_nodetype('coap');
        $separ->set_functor('CONJ');
        $separ->_set_ord(0);
        $_->set_is_member(1), $_->set_parent($separ) for @children;
    }

    # is_member is often missing.
    if ('coap' eq $tnode->nodetype) {
        $tnode->set_functor('CONJ') if 'RSTR' eq $tnode->functor;
        if (! (grep $_->is_member, $tnode->children)
            || grep 'PRED' eq $_->functor, $tnode->children
        ) {
            my %functor;
            ++$functor{ $_->functor } for $tnode->children;
            my $replace = exists $functor{PRED}
                        ? 'PRED'
                        : (sort { $functor{$b} <=> $functor{$b} }
                        keys %functor)[0];
            $_->set_is_member(1) for grep $replace eq $_->functor,
                                     $tnode->children;
        }
    }
}

__PACKAGE__->meta->make_immutable
