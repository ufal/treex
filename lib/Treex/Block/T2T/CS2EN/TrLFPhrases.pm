package Treex::Block::T2T::CS2EN::TrLFPhrases;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

# two Czech words, child t-lemma + formeme & parent t-lemma --> one English t-lemma + mlayer_pos
my %CHILD_PARENT_TO_ONE_NODE = (
    'nástroj|n:2 panel'     => 'toolbar|noun',
    'zavděk|adv vzít'      => 'accept|verb',
    'černý|adj:attr hora'  => 'Montenegro|noun',
    'soudní|adj:attr dvůr' => 'court|noun',
    'jízdní|adj:attr kolo' => 'bicycle|noun',

);

# one Czech word into two English words
my %ONE_NODE_TO_CHILD_PARENT = (
    'premiér|n'         => 'minister|noun prime|adj:attr|adj',
    'premiérka|n'       => 'minister|noun prime|adj:attr|adj',
    'vysokoškolák|n'   => 'student|noun university|n:attr|noun',
    'vysokoškolačka|n' => 'student|noun university|n:attr|noun',
    'Česko|n'           => 'Republic|noun Czech|adj:attr|adj',
    'kurzistka|n'        => 'participant|noun course|n:attr|noun',
    'kurzista|n'         => 'participant|noun course|n:attr|noun',
    'trenčkot|n'        => 'coat|noun trench|n:attr|noun',
    'dalajláma|n'       => 'Lama|noun Dalai|n:attr|noun',
    'Dalajláma|n'       => 'Lama|noun Dalai|n:attr|noun',
    'kinosál|n'         => 'hall|noun cinema|n:attr|noun',
    'spáleniště|n'    => 'area|noun burnt|adj:attr|adj',
    'plovárna|n'        => 'pool|noun swimming|adj:attr|adj',

    'sportovat|v' => 'play|verb sports|n:obj|noun',
    'snídat|v'   => 'have|verb breakfast|n:obj|noun',
    'obědvat|v'  => 'have|verb lunch|n:obj|noun',
    'večeřet|v' => 'have|verb dinner|n:obj|noun',
    'svačit|v'   => 'have|verb snack|n:obj|noun',
    'stačit|v'   => 'be|verb enough|adv|adv',
    'jednat_se|v' => 'be|verb this|n:subj|noun',
);

sub process_ttree {
    my ( $self, $troot ) = @_;

    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
        $self->try_2to1($tnode);
    }

    foreach my $tnode ( $troot->get_descendants( { ordered => 1 } ) ) {
        $self->try_1to2($tnode);
    }
    return;
}

# Translate 2 nodes to 1 -- try merging the node with its parent
sub try_2to1 {

    my ( $self, $tnode ) = @_;
    my $src_tnode  = $tnode->src_tnode() or return 0;
    my $parent     = $tnode->get_parent();
    my $src_parent = $src_tnode->get_parent();

    if ( !$parent->is_root and $parent->t_lemma_origin ne 'rule-TrLFPhrases' ) {

        # dictionary rules
        my $id = $src_tnode->t_lemma . '|' . $src_tnode->formeme . ' ' . $src_parent->t_lemma;

        if ( my $translation = $CHILD_PARENT_TO_ONE_NODE{$id} ) {
            my ( $t_lemma, $mlayer_pos ) = split /\|/, $translation;

            $parent->set_t_lemma($t_lemma);
            $parent->set_attr( 'mlayer_pos', $mlayer_pos );
            $parent->set_t_lemma_origin('rule-TrLFPhrases');

            map { $_->set_parent($parent) } $tnode->get_children();
            $tnode->remove();
            return;
        }
    }
    return;
}

sub try_1to2 {
    my ( $self, $tnode ) = @_;
    return if ( $tnode->t_lemma_origin eq 'rule-TrLFPhrases' );
    my $src_tnode = $tnode->src_tnode() or return 0;
    my $src_formeme_pos = $src_tnode->formeme;
    $src_formeme_pos =~ s/:.*//;

    my $id = $src_tnode->t_lemma . '|' . $src_formeme_pos;

    if ( my $translation = $ONE_NODE_TO_CHILD_PARENT{$id} ) {
        my ( $node_info, $child_info ) = split / /, $translation;

        # create the child node
        my ( $t_lemma, $formeme, $mlayer_pos ) = split /\|/, $child_info;
        my $child = $tnode->create_child(
            {
                t_lemma        => $t_lemma,
                formeme        => $formeme,
                mlayer_pos     => $mlayer_pos,
                t_lemma_origin => 'rule-TrLFPhrases',
                formeme_origin => 'rule-TrLFPhrases',
                clause_number  => $tnode->clause_number,
                nodetype       => 'complex',
            }
        );

        # modify the parent node
        ( $t_lemma, $mlayer_pos ) = split /\|/, $node_info;
        $tnode->set_t_lemma($t_lemma);
        $tnode->set_attr( 'mlayer_pos', $mlayer_pos );
        $tnode->set_t_lemma_origin('rule-TrLFPhrases');

        # fix formeme for the parent: select most probable compatible one
        $self->select_compatible_formeme($tnode);

        # fixing word order: assuming noun groups and light verbs
        if ( $mlayer_pos eq 'verb' and $formeme ne 'n:subj' ) {
            $child->shift_after_node($tnode);
        }
        else {
            $child->shift_before_node($tnode);
        }
        return;
    }
    return;
}

sub select_compatible_formeme {
    my ( $self, $tnode ) = @_;
    my $tm_formemes = $tnode->get_attr('translation_model/formeme_variants');

    foreach my $tm_formeme (@$tm_formemes) {
        if ( $self->is_compatible( $tnode->get_attr('mlayer_pos'), $tm_formeme->{formeme} ) ) {

            $tnode->set_formeme( $tm_formeme->{formeme} );
            $tnode->set_formeme_origin( $tm_formeme->{origin} . '|1st-compatible' );
            last;
        }
    }
    return;
}

sub is_compatible {
    my ( $self, $pos, $formeme ) = @_;

    return 1 if ( $pos eq 'verb'                       and $formeme =~ /^v/ );
    return 1 if ( $pos =~ /^(noun|adj|num)$/           and $formeme =~ /^n/ );
    return 1 if ( $pos =~ /^(adj|num)$/                and $formeme =~ /^adj/ );
    return 1 if ( $pos eq 'adv'                        and $formeme =~ /^adv/ );
    return 1 if ( $pos =~ /^(conj|part|int|punc|sym)$/ and $formeme eq 'x' );

    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::EN2CS::TrLFPhrases

=head1 DESCRIPTION

Rule-based translation of cases which the translation models can't handle (where 2 nodes 
should map onto 1 or 1 node into 2).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
