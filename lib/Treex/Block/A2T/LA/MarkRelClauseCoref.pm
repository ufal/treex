package Treex::Block::A2T::LA::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkRelClauseCoref';



override 'is_relative_word' => sub {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode();
    return ( $a_node and $a_node->lemma eq "qui" );
};


override 'is_allowed_antecedent' => sub {
    my ( $self, $t_antec ) = @_;
    my $a_antec = $t_antec->get_lex_anode();
    return ( $a_antec and $a_antec->tag =~ /^1/ );
};


1;


__END__


=encoding utf-8

=head1 NAME

Treex::Block::A2T::LA::MarkRelClauseCoref

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in SCzechT trees
and store into the C<coref_gram.rf> attribute.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Zdenek Zabokrtsky and Marco Passarotti

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
