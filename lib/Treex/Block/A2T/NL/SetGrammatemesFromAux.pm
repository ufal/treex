package Treex::Block::A2T::NL::SetGrammatemesFromAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetGrammatemesFromAux';

override 'check_anode' => sub {
    my ($self, $tnode, $anode) = @_;

    if ($anode->lemma eq 'niet'){
        $tnode->set_gram_negation('neg1');
    }

    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::NL::SetGrammatemesFromAux

=head1 DESCRIPTION

Language specific addition to L<Treex::Block::A2T::SetGrammatemes> for Dutch 
– setting the negation grammateme based on the negation particle "niet". 

=head1 AUTHOR

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
