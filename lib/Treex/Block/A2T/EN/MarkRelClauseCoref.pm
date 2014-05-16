package Treex::Block::A2T::EN::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkRelClauseCoref';

override 'is_relative_word' => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    return ( $a_node and $a_node->tag =~ /^W/ );
};

override 'is_allowed_antecedent' => sub {
    my ( $self, $t_antec ) = @_;
    my $a_antec = $t_antec->get_lex_anode();
    return ( $a_antec and $a_antec->tag =~ /^(NN|PR|DT)/ );
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::MarkRelClauseCoref

=head1 DESCRIPTION

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected
and stored into the C<coref_gram.rf> attribute.

This file contains rules specific for English (using English Penn Treebank-style
POS tags).

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
