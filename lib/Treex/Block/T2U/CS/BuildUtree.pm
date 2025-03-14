package Treex::Block::T2U::CS::BuildUtree;
use utf8;
use Moose;
extends 'Treex::Block::T2U::BuildUtree';
with 'Treex::Tool::UMR::CS::GrammatemeSetter';

=head1 NAME

 Treex::Block::T2U::CS::BuildUtree - Czech specifics of converting a t-tree to a u-tree

=head1 DESCRIPTION

This module implements actions depending on the lemmas and tags.

=cut

{   my %ASPECT_STATE;
    @ASPECT_STATE{qw{ muset musit mít chtít hodlat moci moct dát_se smět
                      dovést umět lze milovat nenávidět prefereovat přát_si
                      myslet myslit znát vědět souhlasit věřit pochybovat
                      hádat představovat_si znamenat pamatovat_si podezřívat
                      rozumět porozumět vonět zdát_se vidět slyšet znít
                      vlastnit patřit }} = ();
    sub deduce_aspect {
        my ($self, $tnode) = @_;

        return 'state'
            if exists $ASPECT_STATE{ $tnode->t_lemma };

        my $a_node = $tnode->get_lex_anode or return 'state';

        my $tag = $a_node->tag;
        my $m_aspect = substr $tag, -3, 1;
        return 'performance' if 'P' eq $m_aspect;

        my $m_lemma = $a_node->lemma;
        return 'habitual' if 'I' eq $m_aspect && $m_lemma =~ /_\^\(\*4[ai]t\)/;
        return 'activity' if 'I' eq $m_aspect;
        return 'process'  if 'B' eq $m_aspect;
        return 'state'
    }
}

__PACKAGE__->meta->make_immutable
