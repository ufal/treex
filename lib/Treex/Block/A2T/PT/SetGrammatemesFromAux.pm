package Treex::Block::A2T::PT::SetGrammatemesFromAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetGrammatemesFromAux';

sub check_anode {
    my ($self, $tnode, $anode) = @_;

    if ($anode->lemma eq 'mais'){
        $tnode->set_gram_degcmp('comp');
    }

    if ($anode->lemma eq 'não'){
        $tnode->set_gram_negation('neg1');
    }


    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::PT::SetGrammatemesFromAux

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes. 
Grammatemes are set based on the Interset features (and formeme)
of the corresponding auxiliary a-nodes.

In addition to L<Treex::Block::A2T::SetGrammatemesFromAux>,
this block handles Portuguese analytic comparative ("mais feliz")
and negation.


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

Copyright © 2014 by NLX Group, Universidade de Lisboa

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.