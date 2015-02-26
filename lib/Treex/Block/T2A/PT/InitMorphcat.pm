package Treex::Block::T2A::PT::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::InitMorphcat';

after process_tnode => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    my $verbmod     = $t_node->get_attr('gram/verbmod') // '';
    my $tense       = $t_node->get_attr('gram/tense') // '';
    my $deontmod    = $t_node->get_attr('gram/deontmod') // '';

    if($verbmod eq 'cdn' and $tense eq 'sim' and $deontmod eq 'poss') {

        $a_node->iset->set_mood('ind');
        $a_node->iset->set_tense('fut');

        $a_node->iset->set_person('3');
        $a_node->iset->set_number('sing');
    }

    if($verbmod eq 'ind' and $tense =~ /^(post|sim)$/) {

        if ($deontmod =~ /^(vol|decl)$/) {

            if ($tense eq 'sim'){
                $a_node->iset->set_mood('ind');
                $a_node->iset->set_tense('pres');
            }
        }
        else
        {
            $a_node->iset->set_mood('ind');
            $a_node->iset->set_tense('fut');
        }

        $a_node->iset->set_person('3');
        $a_node->iset->set_number('sing');

    }

    # Interset distinguishes imperfect tense (as a subcategory of past tense) and imperfect aspect.
    # There is no such distinction on t-layer, so far, but in Portuguese we need to distinguish
    # "Pretérito Perfeito" from "Pretérito Imperfeito".
    # TODO: distinguish/guess also "Pretérito Mais que Perfeito" ($anode->iset->set_tense('pqp')).
    $a_node->iset->set_tense('imp') if $a_node->match_iset(aspect=>'imp', tense=>'past');

    return;
};

sub should_fill {
    my ($self, $grammateme, $tnode) = @_;

    # In Portuguese, nouns are not marked with definiteness on the a-layer.
    # T2A::PT::AddArticles will add an article for this grammateme.
    return 0 if $grammateme eq 'definiteness';

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 SEE ALSO

L<Treex::Block::T2A::InitMorphcat>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
