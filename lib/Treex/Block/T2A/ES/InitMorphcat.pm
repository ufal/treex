package Treex::Block::T2A::ES::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::InitMorphcat';

after process_tnode => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Interset distinguishes imperfect tense (as a subcategory of past tense) and imperfect aspect.
    # There is no such distinction on t-layer, so far, but in Spanish we need to distinguish
    # "Pretérito Perfecto" from "Pretérito Imperfecto".
    # TODO: distinguish/guess also "Pretérito Pluacuanperfecto" ($anode->iset->set_tense('pqp')).
    $a_node->iset->set_tense('imp') if $a_node->match_iset(aspect=>'imp', tense=>'past');
    return;
};

sub should_fill {
    my ($self, $grammateme, $tnode) = @_;

    # In Portuguese, nouns are not marked with definiteness on the a-layer.
    # T2A::ES::AddArticles will add an article for this grammateme.
    return 0 if $grammateme eq 'definiteness';

    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 SEE ALSO

L<Treex::Block::T2A::InitMorphcat>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
