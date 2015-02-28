package Treex::Block::T2T::CS2EN::FixGrammatemesAfterTransfer;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $t_src = $t_node->src_tnode or return;

    $self->_fix_negation( $t_node, $t_src );

    return;
}

sub _fix_negation {

    my ( $self, $en_t_node, $cs_t_node ) = @_;

    my $en_tlemma = $en_t_node->t_lemma;
    my $cs_tlemma = $cs_t_node->t_lemma;

    # removing negation, where it is lexicalized in English but morphological in Czech
    if (( $en_tlemma    =~ /^absen/    and $cs_tlemma =~ /^pří/ )
        or ( $en_tlemma =~ /^recent/   and $cs_tlemma =~ /^dáv/ )
        or ( $en_tlemma =~ /^necess/   and $cs_tlemma =~ /^zbytn/ )
        or ( $en_tlemma =~ /^ill/      and $cs_tlemma =~ /^moc/ )
        or ( $en_tlemma =~ /^near/     and $cs_tlemma =~ /^dalek/ )
        or ( $en_tlemma =~ /^innoc/    and $cs_tlemma =~ /^vin/ )
        or ( $en_tlemma =~ /^danger/   and $cs_tlemma =~ /^bezp/ )
        or ( $en_tlemma =~ /^risk/     and $cs_tlemma =~ /^bezp/ )
        or ( $en_tlemma =~ /^disadv/   and $cs_tlemma =~ /^výh/ )
        or ( $en_tlemma =~ /^annoy/    and $cs_tlemma =~ /^příj/ )
        or ( $en_tlemma =~ /^harmless/ and $cs_tlemma =~ /^škod/ )
        or ( $en_tlemma =~ /^disgust/  and $cs_tlemma =~ /^chutn/ )
        or ( $en_tlemma =~ /^idle/     and $cs_tlemma =~ /^čin/ )
        or ( $en_tlemma eq 'regardless' and $cs_tlemma =~ /^závisl/ )
        or ( $cs_tlemma eq 'dbalý' )
        or ( $en_tlemma =~ /^fail/           and $cs_tlemma =~ /^zdař/ )
        or ( $en_tlemma =~ /^hat/            and $cs_tlemma =~ /^snáš/ )
        or ( $en_tlemma =~ /^rememb/         and $cs_tlemma =~ /^zapom/ )
        or ( $en_tlemma =~ /^innocent/       and $cs_tlemma =~ /^vinn/ )
        or ( $en_tlemma =~ /^immed/          and $cs_tlemma =~ /^prodl/ )
        or ( $en_tlemma =~ /^wrong/          and $cs_tlemma =~ /^správ/ )
        or ( $en_tlemma =~ /^hazard/         and $cs_tlemma =~ /^bezp/ )
        or ( $en_tlemma =~ /^essent/         and $cs_tlemma =~ /^zbyt/ )
        or ( $en_tlemma =~ /^advers/         and $cs_tlemma =~ /^žádou/ )
        or ( $en_tlemma =~ /^advers/         and $cs_tlemma =~ /^přízn/ )
        or ( $en_tlemma =~ /^vague/          and $cs_tlemma =~ /^určit/ )
        or ( $en_tlemma =~ /^vague/          and $cs_tlemma =~ /^jasn/ )
        or ( $en_tlemma =~ /^unfavour/       and $cs_tlemma =~ /^příz/ )
        or ( $en_tlemma =~ /^requir/         and $cs_tlemma =~ /^zbyt/ )
        or ( $en_tlemma =~ /^opti/           and $cs_tlemma =~ /^povin/ )
        or ( $en_tlemma =~ /^need/           and $cs_tlemma =~ /^zbyt/ )
        or ( $en_tlemma =~ /^ignor/          and $cs_tlemma =~ /^vším/ )
        or ( $en_tlemma =~ /^hostil/         and $cs_tlemma =~ /^přát/ )
        or ( $en_tlemma =~ /^fail/           and $cs_tlemma =~ /^[úu]spě/ )
        or ( $en_tlemma =~ /^void/           and $cs_tlemma =~ /^platn/ )
        or ( $en_tlemma =~ /^excessive/      and $cs_tlemma =~ /^přiměřen/ )
        or ( $en_tlemma =~ /^rash/           and $cs_tlemma =~ /^rozvážn/ )
        or ( $en_tlemma =~ /^tremend/        and $cs_tlemma =~ /^uvěř/ )
        or ( $en_tlemma =~ /^forget/         and $cs_tlemma =~ /^pamat/ )
        or ( $en_tlemma =~ /^disturb/        and $cs_tlemma =~ /^příj/ )
        or ( $en_tlemma =~ /^uneasy/         and $cs_tlemma =~ /^příj/ )
        or ( $en_tlemma =~ /^merciless/      and $cs_tlemma =~ /^(milosr|úpros)/ )
        or ( $en_tlemma =~ /^slopp/          and $cs_tlemma =~ /^(dbal|pořád)/ )
        or ( $en_tlemma =~ /^discontent/     and $cs_tlemma =~ /^(spokoj)/ )
        or ( $en_tlemma =~ /^volat/          and $cs_tlemma =~ /^(stál)/ )
        or ( $en_tlemma =~ /^minor/          and $cs_tlemma =~ /^(zletil)/ )
        or ( $en_tlemma =~ /^([jJ]unk|spam)/ and $cs_tlemma =~ /^vyžáda/ )
        or ( $en_tlemma =~ /^false/          and $cs_tlemma =~ /^správn/ )

        # or ( $en_tlemma =~ /^irritat/      and $cs_tlemma =~ /^z?příjem/ )
        )
    {
        $en_t_node->set_gram_negation('neg0');
    }

    elsif (
        ( $en_tlemma =~ /^fortunate/ and $cs_tlemma =~ /^naneštěstí/ )
        )
    {
        $en_t_node->set_gram_negation('neg1');
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2EN::FixGrammatemesAfterTransfer

=head1 DESCRIPTION

Handle necessary changes in grammatemes after transfer.

Currently, only negation handling is implemented (adding/removing negation
based on Czech and English lemmas).

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
