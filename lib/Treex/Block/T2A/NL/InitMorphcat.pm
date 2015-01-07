package Treex::Block::T2A::NL::InitMorphcat;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::InitMorphcat';

after process_tnode => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Hacking gender: inan => com
    if ( $a_node->match_iset( gender => 'masc', animateness => 'inan' ) ) {
        $a_node->iset->set_gender('com');
        $a_node->iset->set_animateness('');
    }

    # Past/present participle attributes -> set verbform=participle
    if ( $t_node->formeme eq 'v:attr' ) {
        $a_node->iset->set_verbform('part');
    }
    # Finite forms (this will remain with the conjugated verb)
    elsif ( $t_node->formeme =~ /^v:.*(fin|rc)$/ ) {
        $a_node->iset->set_verbform('fin');
    }
    # inifinitves
    elsif ( $t_node->formeme =~ /^v:.*inf$/ ){
        $a_node->iset->set_verbform('inf');
    }
    
    # comparative 'als', 'dan'
    if ( $t_node->formeme eq 'x' and $t_node->t_lemma =~ /^(als|dan)$/ ){
        $a_node->iset->set_pos('conj');
        $a_node->iset->set_conjtype('comp');
    }
    
    # conjunction as rhematizers (PREC)
    if ( $t_node->formeme eq 'x' and $t_node->t_lemma =~ /^(en|maar|of)$/ and not $t_node->get_children() ){
        $a_node->iset->set_pos('conj');
        $a_node->iset->set_conjtype('coor');
    }
    return;
};

sub should_fill {
    my ( $self, $grammateme, $tnode ) = @_;

    # In Dutch, nouns are not marked with definiteness on the a-layer.
    # T2A::NL::AddArticles will add an article for this grammateme.
    return 0 if $grammateme eq 'definiteness';

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 SEE ALSO

L<Treex::Block::T2A::InitMorphcat>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
