package Treex::Block::A2T::BG::SetGrammatemesFromAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetGrammatemesFromAux';

# modal verb -> gram/deontmod mapping
Readonly my %DEONTMOD_FOR_LEMMA => (
    'трябва'   => 'deb',
    'мога'   => 'poss',
    # TODO
    #'should' => 'hrt',
    #'want'   => 'vol',
    #'may'    => 'perm',
    #'might'  => 'perm',
    #'be_able_to' => 'fac',
);

sub check_anode {
    my ($self, $tnode, $anode) = @_;

    if ($anode->lemma eq 'не'){
        $tnode->set_gram_negation('neg1');
    }

    my $deontmod = $DEONTMOD_FOR_LEMMA{$anode->lemma};
    if ($deontmod){
        $tnode->set_gram_deontmod($deontmod);
    }
    if ($anode->lemma eq 'ще'){
        $tnode->set_gram_tense('post');
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::BG::SetGrammatemesFromAux

=head1 DESCRIPTION

In addition to L<Treex::Block::A2T::SetGrammatemesFromAux>,
this block handles Bulgarian negation ("не").

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.