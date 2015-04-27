package Treex::Block::T2A::EN::AddAdjAdvGradation;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # select only negated nodes
    return if ( $t_node->gram_degcmp // '' ) !~ /^(comp|acomp|sup)$/;

    # verbal negation is handled separately
    return if ( $t_node->formeme !~ /^(adj|adv)/ );
    
    # return for adjectives with -er, -est
    return if ( $t_node->t_lemma !~ /([ae]nt|ful|.less|.[ia]ble|ous|ish|ing|some|ual|(?<!ear)ly|^often)$/ );

    my $a_node = $t_node->get_lex_anode() or return;
    
    my $grad_lemma = $t_node->gram_degcmp eq 'sup' ? 'most' : 'more';

    # create the particle node, place it before the $node
    my $grad_node = $a_node->create_child(
        {
            'lemma'        => $grad_lemma,
            'form'         => $grad_lemma,
            'afun'         => 'Adv',
            'morphcat/pos' => '!',
        }
    );
    $grad_node->shift_before_node($a_node);
    $t_node->add_aux_anodes($grad_node);

    # set the a-node's grade to nothing to prevent double gradation ("more better")
    $a_node->set_morphcat_grade('1'); 
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::AddAdjAdvGradation

=head1 DESCRIPTION

Adding 'more' and 'most' for comparative and superlative adjectives and adverbs.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
