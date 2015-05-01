package Treex::Block::T2T::CS2EN::TrLFixTMErrors;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $src_t_node = $t_node->src_tnode or return;

    # mít -> #PersPron (because of Czech pro-drop pronouns, the English pronoun aligns with the Czech verb :-( ) 
    if ( $t_node->t_lemma eq '#PersPron' and $src_t_node->t_lemma eq 'mít' ) {
        $t_node->set_t_lemma('have');
        $t_node->set_attr( 'mlayer_pos', 'verb' );
        $t_node->set_t_lemma_origin('rule-TrLFixTMErrors');
        
        $self->select_compatible_formeme($t_node);
    }
    
    # i -> and
    if ( $t_node->t_lemma eq 'and' and $src_t_node->t_lemma eq 'i' and $t_node->functor eq 'RHEM' ){
        $t_node->set_t_lemma('also');
        $t_node->set_attr( 'mlayer_pos', 'adv' );
        $t_node->set_t_lemma_origin('rule-TrLFixTMErrors');
        
        $self->select_compatible_formeme($t_node);
    }

    # nikdo -> no one    
    if ( $t_node->t_lemma =~ /^(no|one)$/ and $src_t_node->t_lemma eq 'nikdo' ){
        $t_node->set_t_lemma('no_one');
        $t_node->set_attr( 'mlayer_pos', 'noun' );
        $t_node->set_t_lemma_origin('rule-TrLFixTMErrors');
        $self->select_compatible_formeme($t_node);
    }

    # nijak -> in no way    
    if ( $t_node->t_lemma =~ /^(no|way)$/ and $src_t_node->t_lemma eq 'nijak' ){
        $t_node->set_t_lemma('in_no_way');
        $t_node->set_attr( 'mlayer_pos', 'adv' );
        $t_node->set_t_lemma_origin('rule-TrLFixTMErrors');
        $self->select_compatible_formeme($t_node);
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

Treex::Block::T2T::CS2EN::TrLFixTMErrors

=head1 DESCRIPTION

Fix blatant TM errors due to misalignment.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

